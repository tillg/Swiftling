//
//  AppleDocsRetriever.swift
//  Swiftling
//
//  Created by Claude Code on 09.11.25.
//

import Foundation

// MARK: - JSON Decoding Helper

/// Helper to format JSONDecoder errors with detailed path information
fileprivate func formatDecodingError(_ error: Error) -> String {
    func keyPath(from codingPath: [CodingKey], appending key: CodingKey? = nil) -> String {
        let fullPath: [CodingKey]
        if let key = key { fullPath = codingPath + [key] } else { fullPath = codingPath }
        if fullPath.isEmpty { return "<root>" }
        var path = ""
        for k in fullPath {
            if let i = k.intValue {
                path += "[\(i)]"
            } else {
                if !path.isEmpty { path += "." }
                path += k.stringValue
            }
        }
        return path
    }

    switch error {
    case DecodingError.keyNotFound(let key, let context):
        let path = keyPath(from: context.codingPath, appending: key)
        return "Missing key at path '\(path)' – \(context.debugDescription)"
    case DecodingError.typeMismatch(let type, let context):
        let path = keyPath(from: context.codingPath)
        return "Type mismatch for \(type) at path '\(path)' – \(context.debugDescription)"
    case DecodingError.valueNotFound(let type, let context):
        let path = keyPath(from: context.codingPath)
        return "Missing \(type) value at path '\(path)' – \(context.debugDescription)"
    case DecodingError.dataCorrupted(let context):
        let path = keyPath(from: context.codingPath)
        return "Data corrupted at path '\(path)' – \(context.debugDescription)"
    default:
        return error.localizedDescription
    }
}

// MARK: - Apple Docs Retriever

/// KnowledgeRetriever implementation for Apple Developer Documentation
/// Uses sosumi.ai-inspired approach: fetches JSON data and converts to Markdown
final class AppleDocsRetriever: KnowledgeRetriever {
    let sourceIdentifier = "apple-docs"
    let sourceName = "Apple Developer Documentation"

    private let urlSession: URLSession
    private let cache: KnowledgeCache?

    // Safari User-Agent strings for rotation (to avoid detection)
    private let userAgents = [
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Safari/605.1.15",
        "Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    ]

    init(urlSession: URLSession = .shared, cache: KnowledgeCache? = nil) {
        self.urlSession = urlSession
        self.cache = cache
    }

    // MARK: - KnowledgeRetriever Protocol

    func search(query: String, maxResults: Int = 0) async throws -> [SearchResult] {
        // Apple's search endpoint
        let searchURL = buildSearchURL(query: query)
        print("DEBUG: Fetching from Apple Docs: \(searchURL)")

        var request = URLRequest(url: searchURL)
        request.setValue(randomUserAgent(), forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw KnowledgeRetrieverError.unknownError(description: "Invalid response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 404 {
                throw KnowledgeRetrieverError.noResults
            }
            throw KnowledgeRetrieverError.networkError(
                underlying: URLError(.badServerResponse)
            )
        }

        return try parseSearchResults(data, maxResults: maxResults)
    }

    func fetch(_ result: SearchResult) async throws -> DocumentContent {
        print("🔍 DEBUG fetch(): Starting fetch for \(result.url.absoluteString)")

        // Check cache first
        if let cached = await cache?.get(url: result.url) {
            print("🔍 DEBUG fetch(): Found in cache")
            return cached
        }

        print("🔍 DEBUG fetch(): Not in cache, proceeding to fetch")

        // Convert URL to JSON endpoint
        let jsonURL: URL
        do {
            jsonURL = try convertToJSONEndpoint(result.url)
            print("🔍 DEBUG fetch(): Converted to JSON URL: \(jsonURL.absoluteString)")
        } catch {
            print("❌ DEBUG fetch(): Failed to convert URL: \(error)")
            throw error
        }

        // Fetch JSON data
        let jsonData: Data
        do {
            jsonData = try await fetchJSONData(url: jsonURL)
            print("🔍 DEBUG fetch(): Fetched \(jsonData.count) bytes")
        } catch {
            print("❌ DEBUG fetch(): Failed to fetch data: \(error)")
            throw error
        }

        // Parse and convert to Markdown
        let markdown: String
        do {
            markdown = try convertToMarkdown(jsonData, sourceURL: result.url)
            print("🔍 DEBUG fetch(): Converted to markdown (\(markdown.count) chars)")
        } catch {
            print("❌ DEBUG fetch(): Failed to convert to markdown: \(error)")
            throw error
        }

        let content = DocumentContent(
            searchResult: result,
            markdown: markdown,
            rawData: jsonData
        )

        // Cache the result
        await cache?.set(content, for: result.url)

        return content
    }

    // MARK: - Private Helpers

    private func buildSearchURL(query: String) -> URL {
        // Apple's search endpoint (returns HTML)
        var components = URLComponents(string: "https://developer.apple.com/search/")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query)
        ]
        return components.url!
    }

    private func parseSearchResults(_ data: Data, maxResults: Int) throws -> [SearchResult] {
        // Apple returns HTML, not JSON, so we need to parse it
        // Using the same approach as sosumi.ai - looking for li.search-result elements
        guard let html = String(data: data, encoding: .utf8) else {
            throw KnowledgeRetrieverError.parsingError(description: "Invalid HTML encoding")
        }

        print("🔍 DEBUG: Parsing HTML search results (sosumi approach)...")
        print("🔍 DEBUG: HTML length: \(html.count) characters")

        var results: [SearchResult] = []

        // Pattern to match the structure sosumi looks for:
        // <li class="search-result">
        //   <a class="click-analytics-result" href="/documentation/...">Title</a>
        //   <p class="result-description">Description</p>
        // </li>

        // First, find all <li class="search-result"> blocks
        let searchResultPattern = #"<li[^>]*class="[^"]*search-result[^"]*"[^>]*>([\s\S]*?)</li>"#

        guard let searchResultRegex = try? NSRegularExpression(pattern: searchResultPattern, options: [.caseInsensitive]) else {
            throw KnowledgeRetrieverError.parsingError(description: "Invalid regex pattern")
        }

        let nsString = html as NSString
        let resultBlocks = searchResultRegex.matches(in: html, range: NSRange(location: 0, length: nsString.length))

        print("🔍 DEBUG: Found \(resultBlocks.count) search-result blocks")

        // Apply maxResults limit: 0 or negative means unrestricted
        let blocksToProcess = maxResults > 0 ? resultBlocks.prefix(maxResults) : resultBlocks[...]

        var stats = (noLinkMatch: 0, noURL: 0, notDocumentation: 0, extracted: 0)

        for (index, resultBlock) in blocksToProcess.enumerated() {
            guard resultBlock.numberOfRanges >= 2 else { continue }

            let blockRange = resultBlock.range(at: 1)
            guard blockRange.location != NSNotFound else { continue }

            let blockHTML = nsString.substring(with: blockRange)

            // Debug: Print first block to see structure
            if index == 0 {
                print("🔍 DEBUG: First block HTML (first 500 chars):")
                print(String(blockHTML.prefix(500)))
                print("---")
            }

            // Extract the link with class="click-analytics-result"
            // Pattern captures: href, full <a> tag content, title text
            let linkPattern = #"<a([^>]*href="([^"]+)"[^>]*class="[^"]*click-analytics-result[^"]*"[^>]*|[^>]*class="[^"]*click-analytics-result[^"]*"[^>]*href="([^"]+)"[^>]*)>([\s\S]*?)</a>"#

            let blockNSString = blockHTML as NSString
            var linkMatch: NSTextCheckingResult?

            if let regex = try? NSRegularExpression(pattern: linkPattern, options: [.caseInsensitive]) {
                linkMatch = regex.matches(in: blockHTML, range: NSRange(location: 0, length: blockNSString.length)).first
            }

            guard let match = linkMatch,
                  match.numberOfRanges >= 5 else {
                if index == 0 {
                    print("🔍 DEBUG: No link match found in first block")
                }
                stats.noLinkMatch += 1
                continue
            }

            // Extract full <a> tag attributes
            let aTagRange = match.range(at: 1)
            let aTagAttrs = aTagRange.location != NSNotFound ? blockNSString.substring(with: aTagRange) : ""

            // Extract URL from either capture group 2 or 3
            var urlPath = ""
            let urlRange2 = match.range(at: 2)
            let urlRange3 = match.range(at: 3)
            if urlRange2.location != NSNotFound {
                urlPath = blockNSString.substring(with: urlRange2)
            } else if urlRange3.location != NSNotFound {
                urlPath = blockNSString.substring(with: urlRange3)
            } else {
                stats.noURL += 1
                continue
            }

            // Extract title
            let titleRange = match.range(at: 4)
            guard titleRange.location != NSNotFound else {
                stats.noURL += 1
                continue
            }
            let titleHTML = blockNSString.substring(with: titleRange)

            // Clean up title - remove HTML tags
            let title = titleHTML
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "&nbsp;", with: " ")

            // Extract data-result-type attribute
            var resultType: String?
            let typePattern = #"data-result-type="([^"]+)""#
            if let typeRegex = try? NSRegularExpression(pattern: typePattern, options: []),
               let typeMatch = typeRegex.firstMatch(in: aTagAttrs, range: NSRange(location: 0, length: (aTagAttrs as NSString).length)),
               typeMatch.numberOfRanges >= 2 {
                let typeRange = typeMatch.range(at: 1)
                if typeRange.location != NSNotFound {
                    resultType = (aTagAttrs as NSString).substring(with: typeRange)
                }
            }

            // Make URL absolute if it's relative
            if !urlPath.hasPrefix("http") {
                if !urlPath.hasPrefix("/") {
                    urlPath = "/" + urlPath
                }
                urlPath = "https://developer.apple.com" + urlPath
            }

            guard let fullURL = URL(string: urlPath) else {
                if index < 3 {
                    print("🔍 DEBUG: Skipped - invalid URL: \(urlPath)")
                }
                stats.noURL += 1
                continue
            }

            // Only include documentation URLs
            guard fullURL.path.hasPrefix("/documentation/") else {
                if index < 3 {
                    print("🔍 DEBUG: Skipped - not a documentation URL: \(fullURL.path)")
                }
                stats.notDocumentation += 1
                continue
            }

            // Extract breadcrumbs from <ul class="breadcrumb-list">
            var breadcrumbs: [String] = []
            let breadcrumbPattern = #"<ul[^>]*class="[^"]*breadcrumb-list[^"]*"[^>]*>([\s\S]*?)</ul>"#
            if let breadcrumbRegex = try? NSRegularExpression(pattern: breadcrumbPattern, options: [.caseInsensitive]),
               let breadcrumbMatch = breadcrumbRegex.firstMatch(in: blockHTML, range: NSRange(location: 0, length: blockNSString.length)),
               breadcrumbMatch.numberOfRanges >= 2 {
                let breadcrumbRange = breadcrumbMatch.range(at: 1)
                if breadcrumbRange.location != NSNotFound {
                    let breadcrumbHTML = blockNSString.substring(with: breadcrumbRange)
                    // Extract text from each <li> or <a> within breadcrumbs
                    let itemPattern = #"<(?:li|a)[^>]*>([\s\S]*?)</(?:li|a)>"#
                    if let itemRegex = try? NSRegularExpression(pattern: itemPattern, options: [.caseInsensitive]) {
                        let itemMatches = itemRegex.matches(in: breadcrumbHTML, range: NSRange(location: 0, length: (breadcrumbHTML as NSString).length))
                        for itemMatch in itemMatches {
                            if itemMatch.numberOfRanges >= 2 {
                                let itemRange = itemMatch.range(at: 1)
                                if itemRange.location != NSNotFound {
                                    let item = (breadcrumbHTML as NSString).substring(with: itemRange)
                                        .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                                        .trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !item.isEmpty {
                                        breadcrumbs.append(item)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Extract tags from <ul class="tag-list"> or similar
            var tags: [String] = []
            let tagPattern = #"<ul[^>]*class="[^"]*tag-list[^"]*"[^>]*>([\s\S]*?)</ul>"#
            if let tagRegex = try? NSRegularExpression(pattern: tagPattern, options: [.caseInsensitive]),
               let tagMatch = tagRegex.firstMatch(in: blockHTML, range: NSRange(location: 0, length: blockNSString.length)),
               tagMatch.numberOfRanges >= 2 {
                let tagRange = tagMatch.range(at: 1)
                if tagRange.location != NSNotFound {
                    let tagHTML = blockNSString.substring(with: tagRange)
                    // Extract text from each <li> or <span> within tags
                    let itemPattern = #"<(?:li|span)[^>]*>([\s\S]*?)</(?:li|span)>"#
                    if let itemRegex = try? NSRegularExpression(pattern: itemPattern, options: [.caseInsensitive]) {
                        let itemMatches = itemRegex.matches(in: tagHTML, range: NSRange(location: 0, length: (tagHTML as NSString).length))
                        for itemMatch in itemMatches {
                            if itemMatch.numberOfRanges >= 2 {
                                let itemRange = itemMatch.range(at: 1)
                                if itemRange.location != NSNotFound {
                                    let item = (tagHTML as NSString).substring(with: itemRange)
                                        .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                                        .trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !item.isEmpty {
                                        tags.append(item)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Extract description
            let descPattern = #"<p[^>]*class="[^"]*result-description[^"]*"[^>]*>([\s\S]*?)</p>"#
            var description: String?
            if let descRegex = try? NSRegularExpression(pattern: descPattern, options: [.caseInsensitive]) {
                let descMatches = descRegex.matches(in: blockHTML, range: NSRange(location: 0, length: blockNSString.length))
                if let descMatch = descMatches.first, descMatch.numberOfRanges >= 2 {
                    let descRange = descMatch.range(at: 1)
                    if descRange.location != NSNotFound {
                        description = blockNSString.substring(with: descRange)
                            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }

            print("🔍 DEBUG: Extracted result: \(title) -> \(fullURL.absoluteString)")
            if !breadcrumbs.isEmpty {
                print("         Breadcrumbs: \(breadcrumbs.joined(separator: " > "))")
            }
            if let type = resultType {
                print("         Type: \(type)")
            }

            results.append(SearchResult(
                title: title,
                summary: description,
                url: fullURL,
                sourceIdentifier: sourceIdentifier,
                breadcrumbs: breadcrumbs,
                tags: tags,
                resultType: resultType
            ))
            stats.extracted += 1
        }

        guard !results.isEmpty else {
            throw KnowledgeRetrieverError.noResults
        }

        let limitNote = maxResults > 0 ? " (limited to \(maxResults))" : " (unrestricted)"
        print("🔍 DEBUG: Processing stats - noLinkMatch: \(stats.noLinkMatch), noURL: \(stats.noURL), notDocumentation: \(stats.notDocumentation), extracted: \(stats.extracted)")
        print("🔍 DEBUG: Returning \(results.count) search results\(limitNote)")
        return results
    }

    private func convertToJSONEndpoint(_ url: URL) throws -> URL {
        // Convert web URL to JSON data endpoint
        // Pattern 1: https://developer.apple.com/documentation/swift/double
        //         -> https://developer.apple.com/tutorials/data/documentation/swift/double.json
        // Pattern 2: https://developer.apple.com/documentation/swift
        //         -> https://developer.apple.com/tutorials/data/index/swift

        print("🔍 DEBUG: Converting URL to JSON endpoint: \(url.absoluteString)")

        guard url.host == "developer.apple.com" else {
            throw KnowledgeRetrieverError.invalidRequest(
                description: "URL must be from developer.apple.com"
            )
        }

        let path = url.path
        let components = path.split(separator: "/").map(String.init)

        print("🔍 DEBUG: Path components: \(components)")

        guard components.count >= 2, components[0] == "documentation" else {
            throw KnowledgeRetrieverError.invalidRequest(
                description: "Invalid documentation URL format"
            )
        }

        // Framework index (2 components: /documentation/framework)
        if components.count == 2 {
            let framework = components[1]
            let jsonURL = URL(string: "https://developer.apple.com/tutorials/data/index/\(framework)")!
            print("🔍 DEBUG: Framework index URL: \(jsonURL.absoluteString)")
            return jsonURL
        }

        // Individual page (3+ components: /documentation/framework/type/member...)
        let docPath = components.dropFirst().joined(separator: "/")
        let jsonURL = URL(string: "https://developer.apple.com/tutorials/data/documentation/\(docPath).json")!
        print("🔍 DEBUG: Individual page JSON URL: \(jsonURL.absoluteString)")
        return jsonURL
    }

    private func fetchJSONData(url: URL) async throws -> Data {
        print("🔍 DEBUG: Fetching JSON from: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.setValue(randomUserAgent(), forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw KnowledgeRetrieverError.unknownError(description: "Invalid response")
            }

            print("🔍 DEBUG: HTTP Status: \(httpResponse.statusCode)")
            print("🔍 DEBUG: Content-Type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "none")")
            print("🔍 DEBUG: Data size: \(data.count) bytes")

            // Print first 500 chars of response
            if let responseText = String(data: data, encoding: .utf8) {
                print("🔍 DEBUG: Response preview (first 500 chars):")
                print(String(responseText.prefix(500)))
                print("...")
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 404 {
                    throw KnowledgeRetrieverError.notFound(url: url)
                }
                throw KnowledgeRetrieverError.networkError(
                    underlying: URLError(.badServerResponse)
                )
            }

            return data
        } catch let error as KnowledgeRetrieverError {
            throw error
        } catch {
            throw KnowledgeRetrieverError.networkError(underlying: error)
        }
    }

    private func convertToMarkdown(_ data: Data, sourceURL: URL) throws -> String {
        // Debug: Save full JSON to see structure
        if let jsonString = String(data: data, encoding: .utf8) {
            print("🔍 DEBUG: Full JSON structure (first 2000 chars):")
            print(String(jsonString.prefix(2000)))
            print("...")
        }

        // Parse JSON
        let decoder = JSONDecoder()
        let docJSON: AppleDocJSON

        do {
            docJSON = try decoder.decode(AppleDocJSON.self, from: data)
        } catch {
            let errorDetails = formatDecodingError(error)
            print("❌ DEBUG: Decoding failed: \(errorDetails)")
            throw KnowledgeRetrieverError.parsingError(
                description: "Failed to decode Apple Doc JSON: \(errorDetails)"
            )
        }

        // Build Markdown
        var markdown = ""

        // Front matter
        markdown += "---\n"
        markdown += "title: \(docJSON.metadata?.title ?? "Apple Documentation")\n"
        markdown += "source: \(sourceURL.absoluteString)\n"
        markdown += "fetched: \(ISO8601DateFormatter().string(from: Date()))\n"
        markdown += "---\n\n"

        // Title
        if let title = docJSON.metadata?.title {
            markdown += "# \(title)\n\n"
        }

        // Role heading (e.g., "Protocol", "Structure", etc.)
        if let roleHeading = docJSON.metadata?.roleHeading {
            markdown += "_\(roleHeading)_\n\n"
        }

        // Platforms
        if let platforms = docJSON.metadata?.platforms, !platforms.isEmpty {
            markdown += "**Platforms:** "
            markdown += platforms.compactMap { platform in
                if let name = platform.name {
                    if let version = platform.introducedAt {
                        return "\(name) \(version)+"
                    }
                    return name
                }
                return nil
            }.joined(separator: ", ")
            markdown += "\n\n"
        }

        // Abstract
        if let abstract = docJSON.abstract, !abstract.isEmpty {
            markdown += renderContent(abstract)
            markdown += "\n\n"
        }

        // Primary content sections
        if let sections = docJSON.primaryContentSections {
            for section in sections {
                markdown += renderPrimarySection(section)
            }
        }

        // Topic sections
        if let topics = docJSON.topicSections {
            for topic in topics {
                markdown += renderTopicSection(topic, references: docJSON.references)
            }
        }

        // See also sections
        if let seeAlso = docJSON.seeAlsoSections {
            for section in seeAlso {
                markdown += renderSeeAlsoSection(section, references: docJSON.references)
            }
        }

        return markdown
    }

    // MARK: - Markdown Rendering

    private func renderContent(_ items: [ContentItem], depth: Int = 0) -> String {
        guard depth < 50 else { return "" } // Prevent infinite recursion

        var result = ""

        for item in items {
            // Handle items without type
            guard let itemType = item.type else {
                // If no type, try to render content or inline content
                if let content = item.content {
                    result += renderContent(content, depth: depth + 1)
                } else if let inlineContent = item.inlineContent {
                    result += renderInlineContent(inlineContent, depth: depth + 1)
                } else if let text = item.text {
                    result += text
                }
                continue
            }

            switch itemType {
            case "text":
                if let text = item.text {
                    result += text
                }
            case "codeVoice":
                if let code = item.code?.stringValue ?? item.text {
                    result += "`\(code)`"
                }
            case "paragraph":
                if let inlineContent = item.inlineContent {
                    result += renderInlineContent(inlineContent, depth: depth + 1)
                }
                result += "\n\n"
            case "codeListing":
                if let code = item.code?.stringValue {
                    result += "```\(item.syntax ?? "swift")\n\(code)\n```\n\n"
                }
            case "heading":
                let level = item.level ?? 2
                let prefix = String(repeating: "#", count: level)
                if let inlineContent = item.inlineContent {
                    result += "\(prefix) \(renderInlineContent(inlineContent, depth: depth + 1))\n\n"
                }
            case "unorderedList", "orderedList":
                if let listItems = item.items {
                    for listItem in listItems {
                        if let content = listItem.content {
                            let itemText = renderContent(content, depth: depth + 1).trimmingCharacters(in: .whitespacesAndNewlines)
                            result += itemType == "orderedList" ? "1. " : "- "
                            result += itemText + "\n"
                        }
                    }
                    result += "\n"
                }
            case "aside":
                // Render as GitHub-style callout
                let style = item.style ?? "note"
                result += "> [!\(style.uppercased())]\n"
                if let content = item.content {
                    let contentText = renderContent(content, depth: depth + 1)
                    contentText.split(separator: "\n").forEach { line in
                        result += "> \(line)\n"
                    }
                }
                result += "\n"
            default:
                if let content = item.content {
                    result += renderContent(content, depth: depth + 1)
                } else if let inlineContent = item.inlineContent {
                    result += renderInlineContent(inlineContent, depth: depth + 1)
                }
            }
        }

        return result
    }

    private func renderInlineContent(_ items: [InlineContent], depth: Int = 0) -> String {
        guard depth < 20 else { return "" } // Prevent infinite recursion

        var result = ""

        for item in items {
            // Handle items without type
            guard let itemType = item.type else {
                if let text = item.text {
                    result += text
                }
                continue
            }

            switch itemType {
            case "text":
                if let text = item.text {
                    result += text
                }
            case "codeVoice":
                if let code = item.code?.stringValue ?? item.text {
                    result += "`\(code)`"
                }
            case "emphasis":
                if let text = item.text {
                    result += "_\(text)_"
                }
            case "strong":
                if let text = item.text {
                    result += "**\(text)**"
                }
            case "reference":
                if let identifier = item.identifier {
                    // Convert doc:// identifier to text
                    let title = identifier.split(separator: "/").last ?? ""
                    result += "`\(title)`"
                }
            default:
                if let text = item.text {
                    result += text
                }
            }
        }

        return result
    }

    private func renderPrimarySection(_ section: PrimaryContentSection) -> String {
        var result = ""

        // Section heading
        switch section.kind {
        case "declarations":
            result += "## Declaration\n\n"
            if let declarations = section.declarations {
                for declaration in declarations {
                    let code = declaration.tokens.map { $0.text }.joined()
                    result += "```swift\n\(code)\n```\n\n"
                }
            }
        case "parameters":
            result += "## Parameters\n\n"
            if let parameters = section.parameters {
                for param in parameters {
                    result += "- **\(param.name)**: "
                    if let content = param.content {
                        result += renderContent(content).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    result += "\n"
                }
                result += "\n"
            }
        case "content", "discussion":
            if let content = section.content, !content.isEmpty {
                result += renderContent(content)
            }
        default:
            if let content = section.content {
                result += "## \(section.kind.capitalized)\n\n"
                result += renderContent(content)
            }
        }

        return result
    }

    private func renderTopicSection(_ section: TopicSection, references: [String: Reference]?) -> String {
        var result = "## \(section.title)\n\n"

        if let identifiers = section.identifiers, let refs = references {
            for identifier in identifiers {
                if let ref = refs[identifier], let title = ref.title {
                    result += "- `\(title)`"
                    if let abstract = ref.abstract, !abstract.isEmpty {
                        let abstractText = renderContent(abstract).trimmingCharacters(in: .whitespacesAndNewlines)
                        result += " - \(abstractText)"
                    }
                    result += "\n"
                }
            }
            result += "\n"
        }

        return result
    }

    private func renderSeeAlsoSection(_ section: SeeAlsoSection, references: [String: Reference]?) -> String {
        var result = "## See Also\n\n"

        if let refs = references {
            for identifier in section.identifiers {
                if let ref = refs[identifier], let title = ref.title {
                    result += "- `\(title)`\n"
                }
            }
            result += "\n"
        }

        return result
    }

    private func randomUserAgent() -> String {
        userAgents.randomElement() ?? userAgents[0]
    }
}
