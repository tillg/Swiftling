//
//  MarkdownView.swift
//  Swiftling
//
//  Created by Claude Code on 09.11.25.
//

import SwiftUI

/// A view that renders markdown content with proper formatting using SwiftUI's native Markdown support
struct MarkdownView: View {
    let markdown: String

    var body: some View {
        // SwiftUI's Text automatically renders Markdown when given a LocalizedStringKey
        Text(LocalizedStringKey(markdown))
            .textSelection(.enabled)
    }
}

/// Helper view for rendering markdown text blocks with proper formatting
private struct MarkdownTextView: View {
    let markdown: String

    var body: some View {
        // Normalize markdown to ensure proper parsing
        let normalizedMarkdown = normalizeMarkdown(markdown)

        // Try to parse the markdown as AttributedString
        if let attributedString = try? AttributedString(markdown: normalizedMarkdown) {
            Text(attributedString)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            // If parsing fails, show as plain text
            Text(normalizedMarkdown)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Normalizes markdown to ensure headings and other elements are properly formatted
    private func normalizeMarkdown(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        var result: [String] = []
        var previousLineWasBlank = true

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Check if this line is a heading
            if trimmed.hasPrefix("#") {
                // Ensure blank line before heading (unless it's the first line)
                if !result.isEmpty && !previousLineWasBlank {
                    result.append("")
                }
                result.append(line)
                previousLineWasBlank = false
            } else if trimmed.isEmpty {
                result.append(line)
                previousLineWasBlank = true
            } else {
                result.append(line)
                previousLineWasBlank = false
            }
        }

        return result.joined(separator: "\n")
    }
}

/// A more advanced markdown view with better code block support
struct FullMarkdownView: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(parseMarkdownBlocks().enumerated()), id: \.offset) { _, block in
                switch block {
                case .text(let content):
                    // Use SwiftUI's native Markdown rendering for text content
                    MarkdownTextView(markdown: content)

                case .codeBlock(let code, let language):
                    VStack(alignment: .leading, spacing: 4) {
                        if let language = language, !language.isEmpty {
                            Text(language)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.1))
                                .cornerRadius(4)
                        }

                        Text(code)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            #if os(iOS)
                            .background(Color(uiColor: .secondarySystemBackground))
                            #else
                            .background(Color(nsColor: .controlBackgroundColor))
                            #endif
                            .cornerRadius(8)
                    }
                }
            }
        }
    }

    // MARK: - Markdown Block Parsing

    enum MarkdownBlock {
        case text(String)
        case codeBlock(code: String, language: String?)
    }

    private func parseMarkdownBlocks() -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = markdown.components(separatedBy: .newlines)

        var currentTextLines: [String] = []
        var inCodeBlock = false
        var codeBlockLines: [String] = []
        var codeBlockLanguage: String?

        for line in lines {
            // Check for code block delimiter
            if line.hasPrefix("```") {
                if inCodeBlock {
                    // End of code block
                    let code = codeBlockLines.joined(separator: "\n")
                    blocks.append(.codeBlock(code: code, language: codeBlockLanguage))
                    codeBlockLines = []
                    codeBlockLanguage = nil
                    inCodeBlock = false
                } else {
                    // Start of code block
                    // Save any accumulated text (preserve ALL lines including empty ones)
                    if !currentTextLines.isEmpty {
                        // Remove trailing empty lines from text block
                        while currentTextLines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
                            currentTextLines.removeLast()
                        }
                        if !currentTextLines.isEmpty {
                            blocks.append(.text(currentTextLines.joined(separator: "\n")))
                        }
                        currentTextLines = []
                    }

                    inCodeBlock = true
                    // Extract language hint if present
                    let languageHint = line.dropFirst(3).trimmingCharacters(in: .whitespaces)
                    codeBlockLanguage = languageHint.isEmpty ? nil : languageHint
                }
            } else {
                if inCodeBlock {
                    codeBlockLines.append(line)
                } else {
                    currentTextLines.append(line)
                }
            }
        }

        // Add any remaining text
        if !currentTextLines.isEmpty {
            // Remove trailing empty lines
            while currentTextLines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
                currentTextLines.removeLast()
            }
            if !currentTextLines.isEmpty {
                blocks.append(.text(currentTextLines.joined(separator: "\n")))
            }
        }

        // Handle unclosed code block
        if inCodeBlock && !codeBlockLines.isEmpty {
            blocks.append(.codeBlock(code: codeBlockLines.joined(separator: "\n"), language: codeBlockLanguage))
        }

        return blocks
    }
}

#Preview("Simple Markdown") {
    ScrollView {
        MarkdownView(markdown: """
        # Heading 1
        ## Heading 2

        This is **bold** text and this is *italic* text.

        This is ***bold italic*** text.

        Here's a [link](https://example.com).

        ~~Strikethrough text~~

        `Inline code works too`

        - List item 1
        - List item 2
        - List item 3

        1. Numbered item
        2. Another item
        """)
        .padding()
    }
}

#Preview("Code Block Markdown") {
    ScrollView {
        FullMarkdownView(markdown: """
        # Array Documentation

        An ordered, random-access collection.

        ## Overview

        Arrays are one of the most commonly used data types. Use them when you need an **ordered** collection of values.

        You can also use ***bold italic*** text and ~~strikethrough~~ text.

        ## Example

        ```swift
        let numbers = [1, 2, 3, 4, 5]
        for number in numbers {
            print(number)
        }
        ```

        Here's some `inline code` in a paragraph.

        Visit [Apple's website](https://apple.com) for more information.
        """)
        .padding()
    }
}

#Preview("Apple Callouts") {
    ScrollView {
        FullMarkdownView(markdown: MarkdownUtilities.cleanUpMarkdown("""
        # Array Documentation

        Arrays store values of the same type in an ordered list.

        > [!NOTE]
        > The ContiguousArray and ArraySlice types are not bridged; instances of those types always have a contiguous block of memory as their storage.

        ## Performance

        Arrays are optimized for performance.

        > [!WARNING]
        > Modifying an array while iterating over it may cause undefined behavior.

        > [!TIP]
        > Use `reserveCapacity(_:)` to improve performance when you know the approximate size.

        ## Thread Safety

        > [!IMPORTANT]
        > Arrays are not thread-safe. Use appropriate synchronization when accessing arrays from multiple threads.

        Regular text continues here.
        """))
        .padding()
    }
}

#Preview("Heading Test") {
    ScrollView {
        FullMarkdownView(markdown: """
        # Heading 1

        This is some text under heading 1.

        ## Heading 2

        This is some text under heading 2. It should have **bold** and *italic* text.

        ### Heading 3

        - List item 1
        - List item 2
        - List item 3

        ## Another Heading 2

        ```swift
        let array = [1, 2, 3]
        print(array)
        ```

        ## Final Heading

        Regular text with `inline code` and a [link](https://apple.com).
        """)
        .padding()
    }
}
