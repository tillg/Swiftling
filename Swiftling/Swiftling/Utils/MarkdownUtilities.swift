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

    /// Cleans up non-standard markdown elements from Apple's documentation
    /// - Parameter markdown: The raw markdown string
    /// - Returns: Cleaned markdown with Apple-specific elements converted to standard markdown
    static func cleanUpMarkdown(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: .newlines)
        var result: [String] = []
        var inCallout = false
        var calloutType: String?
        var calloutLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Check for callout start: > [!NOTE], > [!WARNING], etc.
            if trimmed.hasPrefix("> [!") && trimmed.hasSuffix("]") {
                // Extract callout type (NOTE, WARNING, TIP, IMPORTANT, etc.)
                let typeStart = trimmed.index(trimmed.startIndex, offsetBy: 4) // Skip "> [!"
                let typeEnd = trimmed.index(before: trimmed.endIndex) // Remove trailing "]"
                calloutType = String(trimmed[typeStart..<typeEnd])
                inCallout = true
                calloutLines = []
                continue
            }

            // Check for callout continuation: lines starting with >
            if inCallout && trimmed.hasPrefix(">") {
                // Remove the leading > and whitespace
                let contentStart = trimmed.index(after: trimmed.startIndex)
                if contentStart < trimmed.endIndex {
                    let content = String(trimmed[contentStart...]).trimmingCharacters(in: .whitespaces)
                    if !content.isEmpty {
                        calloutLines.append(content)
                    }
                }
                continue
            }

            // End of callout - format and add to result
            if inCallout {
                if let type = calloutType, !calloutLines.isEmpty {
                    let formattedType = formatCalloutType(type)
                    let content = calloutLines.joined(separator: " ")
                    // Format as italic text with bold prefix
                    result.append("_**\(formattedType):** \(content)_")
                    result.append("") // Add blank line after callout
                }
                inCallout = false
                calloutType = nil
                calloutLines = []
            }

            // Regular line
            result.append(line)
        }

        // Handle callout at end of document
        if inCallout, let type = calloutType, !calloutLines.isEmpty {
            let formattedType = formatCalloutType(type)
            let content = calloutLines.joined(separator: " ")
            result.append("_**\(formattedType):** \(content)_")
        }

        return result.joined(separator: "\n")
    }

    /// Formats callout type into a user-friendly string
    /// - Parameter type: The callout type (NOTE, WARNING, TIP, etc.)
    /// - Returns: Formatted string (Note, Warning, Tip, etc.)
    private static func formatCalloutType(_ type: String) -> String {
        switch type.uppercased() {
        case "NOTE":
            return "Note"
        case "WARNING":
            return "⚠️ Warning"
        case "TIP":
            return "💡 Tip"
        case "IMPORTANT":
            return "❗ Important"
        case "CAUTION":
            return "⚠️ Caution"
        default:
            // Capitalize first letter of unknown types
            return type.prefix(1).uppercased() + type.dropFirst().lowercased()
        }
    }
}
