//
//  HWSMarkdownCleaner.swift
//  Swiftling
//
//  Created by Claude Code on 09.11.25.
//

import Foundation

/// Cleans up markdown content from HackingWithSwift by removing navigation, promotional content, and UI elements
/// Based on https://github.com/tillg/site2chunks/blob/main/config/hackingwithswift/config.yaml
struct HWSMarkdownCleaner {
    /// Cleans the provided markdown by applying all cleanup rules in order
    func clean(_ markdown: String) -> String {
        var result = markdown

        // Apply all rules in order: structural rules first, then content rules, then cleanup rules
        for rule in allRules {
            result = rule.apply(to: result)
        }

        // Clean up excessive whitespace (matches Python's _normalize_whitespace)
        result = normalizeWhitespace(result)

        return result
    }

    /// Clean up excessive blank lines and trailing whitespace
    /// Matches the Python implementation's _normalize_whitespace method
    private func normalizeWhitespace(_ content: String) -> String {
        // Remove trailing whitespace from each line
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }

        // Reduce multiple blank lines to maximum 2
        var normalized: [String] = []
        var blankCount = 0

        for line in lines {
            if line.isEmpty {
                blankCount += 1
                if blankCount <= 2 {
                    normalized.append(line)
                }
            } else {
                blankCount = 0
                normalized.append(line)
            }
        }

        // Join and ensure file ends with single newline
        let result = normalized.joined(separator: "\n")
        return result.isEmpty ? "" : result.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    // MARK: - All Cleanup Rules

    private var allRules: [CleanupRule] {
        [
            // MARK: Navigation & Footer Removal (Structural)

            // Remove page title when it appears before the actual heading (from <title> tag)
            .regex(
                pattern: #"^.*? – Hacking with Swift\s*\n"#,
                options: []
            ),

            // Remove navigation menu (appears at top of every page)
            .sectionBoundary(
                startMarker: "- [Forums](/forums)",
                endMarker: "- [SUBSCRIBE](/plus)",
                inclusive: true
            ),

            // Remove footer sections starting with store link
            .sectionBoundary(
                startMarker: "[Click here to visit the Hacking with Swift store >>](/store)",
                endMarker: "Link copied to your pasteboard.",
                inclusive: true
            ),

            // Alternative footer pattern (some pages have different footer)
            .sectionBoundary(
                startMarker: "[Back to 100 Days of Swift](/100)",
                endMarker: "Link copied to your pasteboard.",
                inclusive: true
            ),

            // Alternative footer starting with social media links (empty H4 headers)
            .regex(
                pattern: #"####\s*\n\nTwitter\]\(https://twitter\.com/twostraws\).*?Hacking with Swift is ©\d{4} \[Hudson Heavy Industries\]\(https://www\.hudson\.uk\)\."#,
                options: [.dotMatchesLineSeparators]
            ),

            // Remove social sharing blocks with copy-paste text
            .sectionBoundary(
                startMarker: "Alternatively, copy and paste the text below to your preferred social network",
                endMarker: "via @twostraws",
                inclusive: true
            ),

            // Remove "About the Swift Knowledge Base" sections
            .sectionBoundary(
                startMarker: "### About the Swift Knowledge Base",
                endMarker: "Was this page useful? Let us know!",
                inclusive: true
            ),

            // Remove HWS+ membership promotional sections
            .sectionBoundary(
                startMarker: "## Hacking with Swift+ membership includes…",
                endMarker: "#### A free ticket to Unwrap Live every year",
                inclusive: true
            ),

            // Remove interview question "Important notes" section
            .sectionBoundary(
                startMarker: "## Important notes",
                endMarker: "## Related questions",
                inclusive: true
            ),

            // Remove interview question "Related questions" section
            .sectionBoundary(
                startMarker: "## Related questions",
                endMarker: nil,
                inclusive: true
            ),

            // Remove "Review what you learned" boilerplate sections
            .sectionBoundary(
                startMarker: "## Review what you learned",
                endMarker: "## Challenge",
                inclusive: false
            ),

            // MARK: Promotional Content

            // Remove promotional book banner (appears after nav on some pages)
            .exactMatch(
                pattern: "[NEW BOOK: **Code got you started. This gets you *paid*.** >>](/store/everything-but-the-code)",
                maxRemove: -1
            ),

            // Remove "BUY OUR BOOKS" promotional headers
            .exactMatch(
                pattern: "**BUY OUR BOOKS**",
                maxRemove: -1
            ),

            // Remove login status messages
            .exactMatch(
                pattern: "You are not logged in",
                maxRemove: -1
            ),

            .exactMatch(
                pattern: "[Log in or create account](/login)",
                maxRemove: -1
            ),

            .exactMatch(
                pattern: "Link copied to your pasteboard.",
                maxRemove: -1
            ),

            // MARK: UI Elements & Navigation

            // Remove sponsored content blocks
            .regex(
                pattern: #"\*\*SPONSORED\*\*[^\n]*\n\n\[[^\]]+\]\([^\)]+\)\n"#,
                options: []
            ),

            // Remove "Need help?" CTAs
            .linePattern(pattern: #"^Need help\? Tweet me \[@twostraws\]"#),

            // Remove empty header markers (social media section markers and standalone H2)
            .linePattern(pattern: #"^####\s*$"#),

            .regex(
                pattern: #"\n##\s*\n\n"#,
                options: []
            ),

            // Remove "Back to X" navigation links that appear mid-content
            .regex(
                pattern: #"\[Back to [^\]]+\]\([^\)]+\)"#,
                options: []
            ),

            // Remove RSS feed links
            .linePattern(pattern: #"\[Subscribe to our RSS feed\]"#),

            // MARK: Promotional Sections

            // Remove newsletter subscription headings
            .regex(
                pattern: #"### Subscribe to my monthly newsletter\n\nGet a free book delivered.*?\n\nSubscribe"#,
                options: [.dotMatchesLineSeparators]
            ),

            // Remove Slack join sections
            .regex(
                pattern: #"### Join us on Slack!.*?\[JOIN HERE\]\(/slack\)"#,
                options: [.dotMatchesLineSeparators]
            ),

            // Remove "Get the app" promotional sections
            .regex(
                pattern: #"### Get the app!.*?with Unwrap:.*?completely free with no in-app purchases!"#,
                options: [.dotMatchesLineSeparators]
            ),

            // Clean up "About Me" sections in footer
            .regex(
                pattern: #"## About Me\n\nMy name is Paul Hudson.*?Want to know more about me\? Click here.*?\]\."#,
                options: [.dotMatchesLineSeparators]
            ),

            // Remove article listings at end of article pages
            .regex(
                pattern: #"\[More articles\]\(/articles\).*"#,
                options: [.dotMatchesLineSeparators]
            ),

            // Remove "100 Days of Swift/SwiftUI" promotional blocks
            .regex(
                pattern: #"## 100 Days of Swift(?:UI)?\n\n---\n\nThe 100 Days of Swift(?:UI)? is a free collection of videos, tutorials, tests, and more to help you learn Swift(?:UI)? faster\. \[Click here to learn more\]\(/100(?:/swiftui)?\), or watch the video below\."#,
                options: []
            ),

            // Remove "Have some questions about..." chat prompts
            .regex(
                pattern: #"### Have some questions about .+?\?\n\nHit Send below to start a virtual conversation with me\."#,
                options: []
            ),

            // Remove "Found X articles in the Swift Knowledge Base" headers
            .regex(
                pattern: #"### Found \d+ articles? in the \[Swift Knowledge Base\]\(/example-code\) for this category\."#,
                options: []
            ),

            // Remove newsletter subscription headings
            .regex(
                pattern: #"### Subscribe to my monthly newsletter\n\nGet a free book delivered.*?\n\nSubscribe"#,
                options: [.dotMatchesLineSeparators]
            ),

            // MARK: Navigation Elements

            // Remove article category tags
            .regex(
                pattern: #"^######\s+\[[A-Z\s]+\]\(/articles/category/[^\)]+\)"#,
                options: []
            ),

            // Remove "Read Full Article" links
            .linePattern(pattern: #"^\[Read Full Article\]"#),

            // Remove "Continue reading" links
            .linePattern(pattern: #"^\[Continue reading"#),

            // Remove "Read more" links
            .linePattern(pattern: #"^\[Read more"#),

            // Remove "Older Posts" navigation
            .linePattern(pattern: #"^\[Older Posts\]"#),

            // Remove interview questions link
            .linePattern(pattern: #"^\[See the full list of iOS interview questions\]"#),

            // Remove return to review menu link
            .linePattern(pattern: #"^\[Return to Review Menu\]"#),

            // Remove standalone "Subscribe" text
            .linePattern(pattern: #"^Subscribe$"#),

            // MARK: Interactive Elements

            // Remove feedback form sections
            .regex(
                pattern: #"How can this day be improved\?\n\nGreat job on finishing another day!.*?Thank you!"#,
                options: [.dotMatchesLineSeparators]
            ),

            // Remove "share your progress" social media prompts
            .regex(
                pattern: #"## Now share your progress…\n\nIf you use Twitter.*?\[Tweet\]\(https://twitter.com/share\)"#,
                options: [.dotMatchesLineSeparators]
            ),

            // Remove page rating widgets
            .regex(
                pattern: #"Was this page useful\? Let us know!\n\n1\n2\n3\n4\n5\n\n(?:Average rating:.*?\n\n)?Thank you!"#,
                options: [.dotMatchesLineSeparators]
            ),

            // Remove forum reply blocks
            .regex(
                pattern: #"### Reply to this topic…\n\nYou need to \[create an account or log in\]\(/login\?return=[^\)]+\) to reply\.\n\nAll interactions here are governed by our \[code of conduct\]\(/conduct\)\."#,
                options: []
            ),

            // Remove interactive quiz UI elements
            .regex(
                pattern: #"^(?:True|False|Choose Option \d+)\n(?:(?:True|False|Choose Option \d+)\n)+\nCorrect!.*?\n\nOops.*?\n\nContinue$"#,
                options: [.dotMatchesLineSeparators]
            ),

            // MARK: Code & Technical Content

            // Remove Swift version playground download and browse links
            .regex(
                pattern: #"^\[Download all Swift [\d.]+ changes as a playground\]\(/files/playgrounds/swift/playground[^\)]+\)\n \[Link to Swift [\d.]+ changes\]\(/swift/[\d.]+\)\n\n\[Browse changes in all Swift versions\]\(/swift\)"#,
                options: []
            ),

            // Remove author bylines with social media links
            .regex(
                pattern: #"^\[Paul Hudson\]\(/about\).*?@twostraws.*?$"#,
                options: [.dotMatchesLineSeparators]
            ),

            // MARK: Navigation Tables

            // Remove previous/next navigation tables (multi-row format with headers)
            .regex(
                pattern: #"^\|  \|  \|  \|\n\| --- \| --- \| --- \|\n\| \[<.*?\] \|  \| \[.*?>\] \|$"#,
                options: []
            ),

            // Remove single-row navigation tables
            .regex(
                pattern: #"^\|\s\[<\s[^\]]+\]\([^\)]+\)\s\|\s{1,2}\|\s\[[^\]]+\]\([^\)]+\)\s\|$"#,
                options: []
            ),

            // Remove table of contents navigation rows
            .regex(
                pattern: #"^\| \[Table of Contents\].*?\| \| \|$"#,
                options: []
            ),

            // Remove empty table structures
            .regex(
                pattern: #"^\|  \|  \|  \|\n\| --- \| --- \| --- \|$"#,
                options: []
            ),

            // MARK: HWS+ Content

            // Remove HWS+ subscription promotional text
            .regex(
                pattern: #"If you don.t already subscribe, you can start a free trial.*?\.?$"#,
                options: [.caseInsensitive]
            ),

            // Remove HWS+ "SELECT A CATEGORY" navigation section
            .regex(
                pattern: #"^###### SELECT A CATEGORY\n\n(?:- \[(?:\*\*)?.+?(?:\*\*)?\]\(/plus/[^\)]+\)\n)+\n"#,
                options: []
            ),

            // Remove HWS+ "COURSES BY CATEGORY" navigation section
            .regex(
                pattern: #"^###### COURSES BY CATEGORY\n\n(?:- \[(?:\*\*)?.+?(?:\*\*)?\]\(/plus/[^\)]+\)\n)+\n"#,
                options: []
            ),

            // Remove "Watch me answer this question" video CTA links
            .linePattern(pattern: #"^\[Watch me answer this question.*?\]\(/plus/.*?\)$"#),

            // Remove HWS+ membership badges from forum posts
            .regex(
                pattern: #"\[HWS\+\]\(/plus ".*?"\)"#,
                options: []
            ),

            // MARK: Content Teasers & CTAs

            // Remove "Continue Reading >>" truncation teasers
            .regex(
                pattern: #"\.\.\.\s*\[Continue Reading >>?\]\(.*?\)$"#,
                options: []
            ),

            // MARK: Timestamps & Metadata

            // Remove relative timestamps from forum posts
            .regex(
                pattern: #"\s+\d+[dhm]\s*$"#,
                options: []
            ),

            // MARK: Empty Elements Cleanup (Run at end)

            // Remove empty bullet points
            .linePattern(pattern: #"^-\s*$"#),

            // Clean up empty H2 headings left behind after content removal (final pass)
            .regex(
                pattern: #"\n\n##\s*\n"#,
                options: []
            ),
        ]
    }
}

// MARK: - Cleanup Rule Types

/// Represents different types of cleanup rules for markdown content
enum CleanupRule {
    /// Remove content between start and end markers (inclusive or exclusive)
    case sectionBoundary(startMarker: String, endMarker: String?, inclusive: Bool)

    /// Remove exact string matches
    case exactMatch(pattern: String, maxRemove: Int)

    /// Remove content matching a regex pattern
    case regex(pattern: String, options: NSRegularExpression.Options)

    /// Remove lines matching a pattern
    case linePattern(pattern: String)

    /// Applies the rule to the given markdown and returns the cleaned result
    func apply(to markdown: String) -> String {
        switch self {
        case .sectionBoundary(let startMarker, let endMarker, let inclusive):
            return applySectionBoundary(to: markdown, startMarker: startMarker, endMarker: endMarker, inclusive: inclusive)

        case .exactMatch(let pattern, let maxRemove):
            return applyExactMatch(to: markdown, pattern: pattern, maxRemove: maxRemove)

        case .regex(let pattern, let options):
            return applyRegex(to: markdown, pattern: pattern, options: options)

        case .linePattern(let pattern):
            return applyLinePattern(to: markdown, pattern: pattern)
        }
    }

    // MARK: - Rule Implementations

    private func applySectionBoundary(to markdown: String, startMarker: String, endMarker: String?, inclusive: Bool) -> String {
        var result = markdown

        // Handle case where endMarker is nil (remove from start to end of document)
        guard let endMarker = endMarker else {
            if let startRange = result.range(of: startMarker) {
                if inclusive {
                    result.removeSubrange(startRange.lowerBound..<result.endIndex)
                } else {
                    result.removeSubrange(startRange.upperBound..<result.endIndex)
                }
            }
            return result
        }

        // Find and remove all occurrences of the section
        while let startRange = result.range(of: startMarker) {
            // Look for end marker after start marker
            let searchRange = startRange.upperBound..<result.endIndex

            if let endRange = result.range(of: endMarker, range: searchRange) {
                let removalRange: Range<String.Index>
                if inclusive {
                    removalRange = startRange.lowerBound..<endRange.upperBound
                } else {
                    removalRange = startRange.lowerBound..<endRange.lowerBound
                }
                result.removeSubrange(removalRange)
            } else {
                // End marker not found, remove from start to end
                if inclusive {
                    result.removeSubrange(startRange.lowerBound..<result.endIndex)
                } else {
                    result.removeSubrange(startRange.upperBound..<result.endIndex)
                }
                break
            }
        }

        return result
    }

    private func applyExactMatch(to markdown: String, pattern: String, maxRemove: Int) -> String {
        var result = markdown

        if maxRemove == -1 {
            // Remove all occurrences
            while result.contains(pattern) {
                result = result.replacingOccurrences(of: pattern, with: "", options: .literal)
            }
        } else {
            // Remove up to maxRemove occurrences
            for _ in 0..<maxRemove {
                if result.contains(pattern) {
                    result = result.replacingOccurrences(of: pattern, with: "", options: .literal, range: nil, count: 1)
                } else {
                    break
                }
            }
        }

        return result
    }

    private func applyRegex(to markdown: String, pattern: String, options: NSRegularExpression.Options) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            // If regex is invalid, return original markdown
            print("⚠️ Invalid regex pattern: \(pattern)")
            return markdown
        }

        let range = NSRange(markdown.startIndex..., in: markdown)
        let result = regex.stringByReplacingMatches(in: markdown, options: [], range: range, withTemplate: "")

        return result
    }

    private func applyLinePattern(to markdown: String, pattern: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            // If regex is invalid, return original markdown
            print("⚠️ Invalid line pattern: \(pattern)")
            return markdown
        }

        let lines = markdown.components(separatedBy: .newlines)
        let filtered = lines.filter { line in
            let range = NSRange(line.startIndex..., in: line)
            return regex.firstMatch(in: line, range: range) == nil
        }

        return filtered.joined(separator: "\n")
    }
}

// MARK: - String Extension for replacingOccurrences with count

private extension String {
    /// Replace occurrences of a substring with a specified maximum count
    func replacingOccurrences(of target: String, with replacement: String, options: CompareOptions, range searchRange: Range<Index>?, count: Int) -> String {
        var result = self
        if let range = result.range(of: target, options: options, range: searchRange) {
            result.replaceSubrange(range, with: replacement)
        }
        return result
    }
}
