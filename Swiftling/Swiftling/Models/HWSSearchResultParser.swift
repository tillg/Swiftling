//
//  HWSSearchResultParser.swift
//  Swiftling
//
//  Created by Claude Code on 09.11.25.
//

import Foundation

/// Parses HTML search results from HackingWithSwift.com
struct HWSSearchResultParser: Sendable {

    nonisolated init() {}

    /// Parse HTML from a HackingWithSwift search results page
    /// - Parameter html: The HTML content from the search results page
    /// - Returns: Array of parsed search result items
    /// - Throws: KnowledgeRetrieverError if parsing fails
    nonisolated func parse(_ html: String) throws -> [HWSSearchResultItem] {
        var results: [HWSSearchResultItem] = []

        // HWS search results are contained in divs with class "result"
        // Each result typically has:
        // - A link (<a href="...">) with the title
        // - A summary/snippet
        // - Sometimes a category or type indicator

        // Strategy: Extract each result block and parse its components
        // We'll use regex to find result blocks and extract key information

        // Pattern to match result divs (flexible to handle variations)
        // Looking for: <div class="result">...</div> or similar structures
        let resultPattern = #"<div[^>]*class="[^"]*result[^"]*"[^>]*>(.*?)</div>"#
        let resultRegex = try NSRegularExpression(pattern: resultPattern, options: [.dotMatchesLineSeparators])

        let resultMatches = resultRegex.matches(
            in: html,
            options: [],
            range: NSRange(html.startIndex..., in: html)
        )

        // If we don't find results with the above pattern, try alternative patterns
        if resultMatches.isEmpty {
            // Try alternative: look for links in a list or article structure
            return try parseAlternativeStructure(html)
        }

        for match in resultMatches {
            guard match.numberOfRanges >= 2,
                  let contentRange = Range(match.range(at: 1), in: html) else {
                continue
            }

            let resultHTML = String(html[contentRange])

            if let item = try? parseResultItem(resultHTML) {
                results.append(item)
            }
        }

        return results
    }

    /// Parse an alternative HTML structure (for cases where result divs aren't found)
    nonisolated private func parseAlternativeStructure(_ html: String) throws -> [HWSSearchResultItem] {
        var results: [HWSSearchResultItem] = []

        // Alternative strategy: Look for links that appear to be search results
        // Typically these are in <a href="/articles/..."> or <a href="/example-code/...">
        let linkPattern = #"<a\s+href="(/[^"]+)"[^>]*>(.*?)</a>"#
        let linkRegex = try NSRegularExpression(pattern: linkPattern, options: [.dotMatchesLineSeparators])

        let linkMatches = linkRegex.matches(
            in: html,
            options: [],
            range: NSRange(html.startIndex..., in: html)
        )

        for match in linkMatches {
            guard match.numberOfRanges >= 3,
                  let urlRange = Range(match.range(at: 1), in: html),
                  let titleRange = Range(match.range(at: 2), in: html) else {
                continue
            }

            let urlPath = String(html[urlRange])
            let titleHTML = String(html[titleRange])

            // Filter out navigation links and focus on content links
            if isContentLink(urlPath) {
                // Clean HTML tags from title
                let title = stripHTMLTags(titleHTML)

                // Create URL
                guard let url = URL(string: "https://www.hackingwithswift.com\(urlPath)") else {
                    continue
                }

                // Determine content type from URL
                let contentType = determineContentType(from: urlPath)

                // Extract breadcrumbs if available (from URL structure)
                let breadcrumbs = extractBreadcrumbs(from: urlPath)

                results.append(HWSSearchResultItem(
                    title: title,
                    url: url,
                    summary: nil,
                    contentType: contentType,
                    breadcrumbs: breadcrumbs
                ))
            }
        }

        return results
    }

    /// Parse a single result item HTML block
    nonisolated private func parseResultItem(_ html: String) throws -> HWSSearchResultItem {
        // Extract title and URL from link
        let linkPattern = #"<a\s+href="([^"]+)"[^>]*>(.*?)</a>"#
        let linkRegex = try NSRegularExpression(pattern: linkPattern, options: [.dotMatchesLineSeparators])

        guard let linkMatch = linkRegex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
              linkMatch.numberOfRanges >= 3,
              let urlRange = Range(linkMatch.range(at: 1), in: html),
              let titleRange = Range(linkMatch.range(at: 2), in: html) else {
            throw KnowledgeRetrieverError.parsingError(description: "Could not extract link from result item")
        }

        let urlString = String(html[urlRange])
        let titleHTML = String(html[titleRange])

        // Clean HTML from title
        let title = stripHTMLTags(titleHTML)

        // Create full URL
        let fullURL: URL
        if urlString.starts(with: "http") {
            guard let url = URL(string: urlString) else {
                throw KnowledgeRetrieverError.parsingError(description: "Invalid URL: \(urlString)")
            }
            fullURL = url
        } else {
            guard let url = URL(string: "https://www.hackingwithswift.com\(urlString)") else {
                throw KnowledgeRetrieverError.parsingError(description: "Invalid URL: \(urlString)")
            }
            fullURL = url
        }

        // Extract summary/snippet if available
        let summary = extractSummary(from: html)

        // Determine content type from URL
        let contentType = determineContentType(from: urlString)

        // Extract breadcrumbs
        let breadcrumbs = extractBreadcrumbs(from: urlString)

        return HWSSearchResultItem(
            title: title,
            url: fullURL,
            summary: summary,
            contentType: contentType,
            breadcrumbs: breadcrumbs
        )
    }

    /// Extract summary/snippet from result HTML
    nonisolated private func extractSummary(from html: String) -> String? {
        // Look for common summary patterns
        let patterns = [
            #"<p[^>]*class="[^"]*summary[^"]*"[^>]*>(.*?)</p>"#,
            #"<p[^>]*>(.*?)</p>"#,
            #"<div[^>]*class="[^"]*snippet[^"]*"[^>]*>(.*?)</div>"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
               let match = regex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
               match.numberOfRanges >= 2,
               let summaryRange = Range(match.range(at: 1), in: html) {
                let summaryHTML = String(html[summaryRange])
                let summary = stripHTMLTags(summaryHTML).trimmingCharacters(in: .whitespacesAndNewlines)
                if !summary.isEmpty {
                    return summary
                }
            }
        }

        return nil
    }

    /// Determine content type from URL path
    nonisolated private func determineContentType(from urlPath: String) -> String? {
        if urlPath.contains("/articles/") {
            return "article"
        } else if urlPath.contains("/example-code/") {
            return "example-code"
        } else if urlPath.contains("/quick-start/") {
            return "quick-start"
        } else if urlPath.contains("/100/") {
            return "100-days"
        } else if urlPath.contains("/books/") {
            return "book"
        } else if urlPath.contains("/plus/") {
            return "hws-plus"
        } else if urlPath.contains("/forums/") {
            return "forum"
        } else if urlPath.contains("/swift/") {
            return "swift-version"
        } else if urlPath.contains("/interview/") {
            return "interview-question"
        }
        return nil
    }

    /// Extract breadcrumbs from URL path
    nonisolated private func extractBreadcrumbs(from urlPath: String) -> [String] {
        var breadcrumbs: [String] = []

        // Remove leading slash and query parameters
        var path = urlPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if let queryIndex = path.firstIndex(of: "?") {
            path = String(path[..<queryIndex])
        }

        let components = path.split(separator: "/").map(String.init)

        // Convert path components to readable breadcrumbs
        for component in components {
            // Skip numeric IDs and common patterns
            if component.allSatisfy({ $0.isNumber }) {
                continue
            }

            // Convert kebab-case to title case
            let readable = component
                .replacingOccurrences(of: "-", with: " ")
                .capitalized

            if !readable.isEmpty {
                breadcrumbs.append(readable)
            }
        }

        return breadcrumbs
    }

    /// Check if a URL path is a content link (not navigation)
    nonisolated private func isContentLink(_ urlPath: String) -> Bool {
        let contentPrefixes = [
            "/articles/",
            "/example-code/",
            "/quick-start/",
            "/100/",
            "/books/",
            "/plus/",
            "/swift/",
            "/interview/"
        ]

        return contentPrefixes.contains { urlPath.starts(with: $0) }
    }

    /// Strip HTML tags from a string
    nonisolated private func stripHTMLTags(_ html: String) -> String {
        var result = html

        // Remove HTML tags
        let tagPattern = #"<[^>]+>"#
        if let regex = try? NSRegularExpression(pattern: tagPattern, options: []) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }

        // Decode HTML entities
        result = decodeHTMLEntities(result)

        // Clean up whitespace
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        return result
    }

    /// Decode common HTML entities
    nonisolated private func decodeHTMLEntities(_ text: String) -> String {
        var result = text

        let entities: [(String, String)] = [
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&#39;", "'"),
            ("&apos;", "'"),
            ("&nbsp;", " "),
            ("&#8217;", "'"),
            ("&#8220;", "\""),
            ("&#8221;", "\""),
            ("&hellip;", "..."),
            ("&mdash;", "—"),
            ("&ndash;", "–")
        ]

        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }

        return result
    }
}

// MARK: - Search Result Item

/// Represents a parsed search result item from HackingWithSwift
struct HWSSearchResultItem: Sendable {
    let title: String
    let url: URL
    let summary: String?
    let contentType: String?
    let breadcrumbs: [String]

    /// Convert to SearchResult for use with KnowledgeRetriever protocol
    nonisolated func toSearchResult() -> SearchResult {
        SearchResult(
            title: title,
            summary: summary,
            url: url,
            sourceIdentifier: "hackingwithswift",
            breadcrumbs: breadcrumbs,
            tags: contentType.map { [$0] } ?? [],
            resultType: contentType
        )
    }
}
