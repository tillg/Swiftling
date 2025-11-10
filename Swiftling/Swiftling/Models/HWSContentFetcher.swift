//
//  HWSContentFetcher.swift
//  Swiftling
//
//  Created by Claude Code on 09.11.25.
//

import Foundation

/// Fetches HTML content from HackingWithSwift and converts it to clean markdown
struct HWSContentFetcher: Sendable {
    private let cleaner = HWSMarkdownCleaner()
    private let urlSession: URLSession
    private let skipCleaning: Bool

    init(urlSession: URLSession = .shared, skipCleaning: Bool = false) {
        self.urlSession = urlSession
        self.skipCleaning = skipCleaning
    }

    /// Fetch a page and convert it to cleaned markdown
    /// - Parameter url: The URL to fetch
    /// - Returns: Cleaned markdown content
    /// - Throws: KnowledgeRetrieverError on failure
    func fetch(url: URL) async throws -> String {
        // 1. Fetch HTML
        let html = try await fetchHTML(url: url)

        // 2. Convert to markdown
        let markdown = htmlToMarkdown(html)

        // 3. Apply cleanup rules (unless skipped for debugging)
        if skipCleaning {
            return markdown
        }
        let cleanedMarkdown = cleaner.clean(markdown)

        return cleanedMarkdown
    }

    // MARK: - HTML Fetching

    private func fetchHTML(url: URL) async throws -> String {
        let (data, response) = try await urlSession.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw KnowledgeRetrieverError.networkError(
                underlying: URLError(.badServerResponse)
            )
        }

        switch httpResponse.statusCode {
        case 200:
            guard let html = String(data: data, encoding: .utf8) else {
                throw KnowledgeRetrieverError.parsingError(
                    description: "Could not decode HTML as UTF-8"
                )
            }
            return html

        case 404:
            throw KnowledgeRetrieverError.notFound(url: url)

        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { TimeInterval($0) }
            throw KnowledgeRetrieverError.rateLimitExceeded(retryAfter: retryAfter)

        case 401, 403:
            throw KnowledgeRetrieverError.authenticationFailed

        default:
            throw KnowledgeRetrieverError.networkError(
                underlying: URLError(.badServerResponse)
            )
        }
    }

    // MARK: - HTML to Markdown Conversion

    /// Strip navigation, header, and footer elements from HTML
    private func stripNavigationElements(_ html: String) -> String {
        var result = html

        // Remove <nav> tags and their content
        if let regex = try? NSRegularExpression(pattern: #"<nav[^>]*>.*?</nav>"#, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            result = regex.stringByReplacingMatches(in: result, options: [], range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }

        // Remove <header> tags and their content
        if let regex = try? NSRegularExpression(pattern: #"<header[^>]*>.*?</header>"#, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            result = regex.stringByReplacingMatches(in: result, options: [], range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }

        // Remove <footer> tags and their content
        if let regex = try? NSRegularExpression(pattern: #"<footer[^>]*>.*?</footer>"#, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            result = regex.stringByReplacingMatches(in: result, options: [], range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }

        // Remove <aside> tags (sidebars, related content)
        if let regex = try? NSRegularExpression(pattern: #"<aside[^>]*>.*?</aside>"#, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            result = regex.stringByReplacingMatches(in: result, options: [], range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }

        return result
    }

    /// Convert HTML to markdown
    /// Basic implementation focusing on main content area and common elements
    private func htmlToMarkdown(_ html: String) -> String {
        var result = html

        // 0. Strip navigation, header, and footer elements first (at HTML level)
        result = stripNavigationElements(result)

        // 1. Extract main content area (usually <article> or <main> tag)
        result = extractMainContent(result)

        // 2. Convert block-level elements
        result = convertHeadings(result)
        result = convertCodeBlocks(result)
        result = convertLists(result)
        result = convertBlockquotes(result)
        result = convertTables(result)
        result = convertParagraphs(result)
        result = convertHorizontalRules(result)

        // 3. Convert inline elements
        result = convertLinks(result)
        result = convertImages(result)
        result = convertStrong(result)
        result = convertEmphasis(result)
        result = convertInlineCode(result)

        // 4. Strip remaining HTML tags
        result = stripScriptAndStyle(result)
        result = stripRemainingTags(result)

        // 5. Clean up whitespace
        result = cleanupWhitespace(result)

        return result
    }

    /// Extract main content area from HTML
    private func extractMainContent(_ html: String) -> String {
        // Try to find content in priority order:
        // 1. Article body with specific classes (HWS uses these)
        // 2. <article> tags
        // 3. <main> tags
        // 4. Generic content divs
        //
        // Note: Using greedy matching (.* instead of .*?) to capture all content
        // including nested divs. The cleaner will remove unwanted parts later.
        let patterns = [
            #"<div[^>]*class="[^"]*article-body[^"]*"[^>]*>(.*)</div>"#,
            #"<div[^>]*class="[^"]*post-content[^"]*"[^>]*>(.*)</div>"#,
            #"<div[^>]*class="[^"]*entry-content[^"]*"[^>]*>(.*)</div>"#,
            #"<article[^>]*>(.*)</article>"#,
            #"<main[^>]*>(.*)</main>"#,
            #"<div[^>]*id="[^"]*content[^"]*"[^>]*>(.*)</div>"#,
            #"<div[^>]*class="[^"]*content[^"]*"[^>]*>(.*)</div>"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                let matches = regex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
                // Use the last match to get the outermost div rather than nested ones
                if let match = matches.last,
                   match.numberOfRanges >= 2,
                   let contentRange = Range(match.range(at: 1), in: html) {
                    return String(html[contentRange])
                }
            }
        }

        // If no main content area found, return full HTML
        return html
    }

    /// Convert HTML headings to markdown
    private func convertHeadings(_ html: String) -> String {
        var result = html

        // Convert h1-h6 to markdown headings
        for level in 1...6 {
            let hashes = String(repeating: "#", count: level)
            // Can't use raw strings with interpolation, so use regular strings with escaped backslashes
            let pattern = "<h\(level)[^>]*>(.*?)</h\(level)>"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: "\n\n\(hashes) $1\n\n"
                )
            }
        }

        return result
    }

    /// Convert code blocks to markdown
    private func convertCodeBlocks(_ html: String) -> String {
        var result = html

        // Match <pre><code class="language-swift">...</code></pre>
        let pattern = #"<pre[^>]*>\s*<code[^>]*class="[^"]*language-([^"\s]+)[^"]*"[^>]*>(.*?)</code>\s*</pre>"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "\n\n```$1\n$2\n```\n\n"
            )
        }

        // Match <pre><code>...</code></pre> (no language specified)
        let plainPattern = #"<pre[^>]*>\s*<code[^>]*>(.*?)</code>\s*</pre>"#
        if let regex = try? NSRegularExpression(pattern: plainPattern, options: [.dotMatchesLineSeparators]) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "\n\n```\n$1\n```\n\n"
            )
        }

        // Match <pre>...</pre> (no code tag)
        let prePattern = #"<pre[^>]*>(.*?)</pre>"#
        if let regex = try? NSRegularExpression(pattern: prePattern, options: [.dotMatchesLineSeparators]) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "\n\n```\n$1\n```\n\n"
            )
        }

        return result
    }

    /// Convert lists to markdown
    private func convertLists(_ html: String) -> String {
        var result = html

        // Convert unordered lists
        result = convertUnorderedLists(result)

        // Convert ordered lists
        result = convertOrderedLists(result)

        return result
    }

    private func convertUnorderedLists(_ html: String) -> String {
        var result = html

        // Convert <ul> and <li> tags
        // First, mark list items
        let liPattern = #"<li[^>]*>(.*?)</li>"#
        if let regex = try? NSRegularExpression(pattern: liPattern, options: [.dotMatchesLineSeparators]) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "\n- $1"
            )
        }

        // Remove <ul> tags
        result = result.replacingOccurrences(of: #"</?ul[^>]*>"#, with: "\n", options: .regularExpression)

        return result
    }

    private func convertOrderedLists(_ html: String) -> String {
        var result = html

        // Convert <ol> and <li> tags
        let liPattern = #"<li[^>]*>(.*?)</li>"#
        if let regex = try? NSRegularExpression(pattern: liPattern, options: [.dotMatchesLineSeparators]) {
            // Note: This is simplified - we're using "1." for all items
            // A more sophisticated implementation would track numbering
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "\n1. $1"
            )
        }

        // Remove <ol> tags
        result = result.replacingOccurrences(of: #"</?ol[^>]*>"#, with: "\n", options: .regularExpression)

        return result
    }

    /// Convert blockquotes to markdown
    private func convertBlockquotes(_ html: String) -> String {
        var result = html

        let pattern = #"<blockquote[^>]*>(.*?)</blockquote>"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "\n\n> $1\n\n"
            )
        }

        return result
    }

    /// Convert tables to markdown (basic implementation)
    private func convertTables(_ html: String) -> String {
        // Tables are complex - for now, just preserve them as-is
        // The cleanup rules will handle removing navigation tables
        return html
    }

    /// Convert paragraphs to markdown
    private func convertParagraphs(_ html: String) -> String {
        var result = html

        let pattern = #"<p[^>]*>(.*?)</p>"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "\n\n$1\n\n"
            )
        }

        return result
    }

    /// Convert horizontal rules to markdown
    private func convertHorizontalRules(_ html: String) -> String {
        var result = html

        result = result.replacingOccurrences(of: #"<hr[^>]*>"#, with: "\n\n---\n\n", options: .regularExpression)

        return result
    }

    /// Convert links to markdown
    private func convertLinks(_ html: String) -> String {
        var result = html

        let pattern = #"<a[^>]*href="([^"]+)"[^>]*>(.*?)</a>"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "[$2]($1)"
            )
        }

        return result
    }

    /// Convert images to markdown
    private func convertImages(_ html: String) -> String {
        var result = html

        let pattern = #"<img[^>]*src="([^"]+)"[^>]*alt="([^"]*)"[^>]*>"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "![$2]($1)"
            )
        }

        // Also handle images without alt text
        let noAltPattern = #"<img[^>]*src="([^"]+)"[^>]*>"#
        if let regex = try? NSRegularExpression(pattern: noAltPattern, options: []) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "![]($1)"
            )
        }

        return result
    }

    /// Convert strong/bold to markdown
    private func convertStrong(_ html: String) -> String {
        var result = html

        let patterns = [
            #"<strong[^>]*>(.*?)</strong>"#,
            #"<b[^>]*>(.*?)</b>"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: "**$1**"
                )
            }
        }

        return result
    }

    /// Convert emphasis/italic to markdown
    private func convertEmphasis(_ html: String) -> String {
        var result = html

        let patterns = [
            #"<em[^>]*>(.*?)</em>"#,
            #"<i[^>]*>(.*?)</i>"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: "*$1*"
                )
            }
        }

        return result
    }

    /// Convert inline code to markdown
    private func convertInlineCode(_ html: String) -> String {
        var result = html

        let pattern = #"<code[^>]*>(.*?)</code>"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "`$1`"
            )
        }

        return result
    }

    /// Strip script and style tags
    private func stripScriptAndStyle(_ html: String) -> String {
        var result = html

        // Remove script tags and their content
        result = result.replacingOccurrences(
            of: #"<script[^>]*>.*?</script>"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        // Remove style tags and their content
        result = result.replacingOccurrences(
            of: #"<style[^>]*>.*?</style>"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        return result
    }

    /// Strip remaining HTML tags
    private func stripRemainingTags(_ html: String) -> String {
        var result = html

        // Remove all remaining HTML tags
        let tagPattern = #"<[^>]+>"#
        if let regex = try? NSRegularExpression(pattern: tagPattern, options: []) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: " "  // Replace with space to avoid words running together
            )
        }

        // Clean up multiple spaces
        result = result.replacingOccurrences(
            of: #"  +"#,
            with: " ",
            options: .regularExpression
        )

        // Decode HTML entities
        result = decodeHTMLEntities(result)

        return result
    }

    /// Clean up excessive whitespace
    private func cleanupWhitespace(_ markdown: String) -> String {
        var result = markdown

        // Remove lines that are only whitespace
        let lines = result.components(separatedBy: .newlines)
        let nonEmptyLines = lines.map { line in
            line.trimmingCharacters(in: .whitespaces).isEmpty ? "" : line
        }
        result = nonEmptyLines.joined(separator: "\n")

        // Replace multiple consecutive newlines with max 2
        result = result.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )

        // Remove whitespace-only lines more aggressively
        result = result.replacingOccurrences(
            of: #"\n[ \t]+\n"#,
            with: "\n\n",
            options: .regularExpression
        )

        // Trim leading and trailing whitespace
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        return result
    }

    /// Decode HTML entities
    private func decodeHTMLEntities(_ text: String) -> String {
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
            ("&ndash;", "–"),
            ("&#x2F;", "/"),
            ("&#x27;", "'"),
            ("&copy;", "©"),
            ("&reg;", "®"),
            ("&trade;", "™")
        ]

        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }

        // Handle numeric entities (&#NNN;)
        let numericPattern = #"&#(\d+);"#
        if let regex = try? NSRegularExpression(pattern: numericPattern, options: []) {
            let matches = regex.matches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result)
            )

            // Process matches in reverse to maintain string indices
            for match in matches.reversed() {
                if match.numberOfRanges >= 2,
                   let fullRange = Range(match.range(at: 0), in: result),
                   let numberRange = Range(match.range(at: 1), in: result),
                   let code = Int(result[numberRange]),
                   let scalar = Unicode.Scalar(code) {
                    result.replaceSubrange(fullRange, with: String(Character(scalar)))
                }
            }
        }

        return result
    }
}
