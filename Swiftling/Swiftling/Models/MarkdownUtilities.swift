//
//  MarkdownUtilities.swift
//  Swiftling
//
//  Created by Claude Code on 09.11.25.
//

import Foundation

enum MarkdownUtilities {
    /// Strips YAML frontmatter (--- delimited metadata) from markdown content
    /// - Parameter markdown: The raw markdown string
    /// - Returns: Markdown content without frontmatter
    static func stripFrontmatter(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: .newlines)

        // Check if markdown starts with frontmatter delimiter
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
            return markdown
        }

        // Find the closing delimiter
        var frontmatterEndIndex = 0
        for (index, line) in lines.dropFirst().enumerated() {
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                frontmatterEndIndex = index + 2 // +1 for dropFirst(), +1 to skip the closing ---
                break
            }
        }

        // If no closing delimiter found, return original
        guard frontmatterEndIndex > 0 && frontmatterEndIndex < lines.count else {
            return markdown
        }

        // Return content after frontmatter
        let contentLines = Array(lines.dropFirst(frontmatterEndIndex))
        return contentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Extracts frontmatter metadata as a dictionary
    /// - Parameter markdown: The raw markdown string
    /// - Returns: Dictionary of frontmatter key-value pairs
    static func extractFrontmatter(_ markdown: String) -> [String: String] {
        let lines = markdown.components(separatedBy: .newlines)

        // Check if markdown starts with frontmatter delimiter
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
            return [:]
        }

        // Find the closing delimiter and extract frontmatter lines
        var frontmatterLines: [String] = []
        for line in lines.dropFirst() {
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                break
            }
            frontmatterLines.append(line)
        }

        // Parse simple key: value pairs
        var metadata: [String: String] = [:]
        for line in frontmatterLines {
            let components = line.components(separatedBy: ":")
            guard components.count >= 2 else { continue }

            let key = components[0].trimmingCharacters(in: .whitespaces)
            let value = components.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
            metadata[key] = value
        }

        return metadata
    }
}
