//
//  MarkdownView.swift
//  Swiftling
//
//  Created by Claude Code on 09.11.25.
//

import SwiftUI

/// A view that renders markdown content with proper formatting
struct MarkdownView: View {
    let markdown: String

    var body: some View {
        if let attributedString = try? AttributedString(markdown: markdown, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Text(attributedString)
                .textSelection(.enabled)
        } else if let attributedString = try? AttributedString(markdown: markdown) {
            Text(attributedString)
                .textSelection(.enabled)
        } else {
            // Fallback to plain text if markdown parsing fails
            Text(markdown)
                .textSelection(.enabled)
        }
    }
}

/// A more advanced markdown view with better code block support
struct FullMarkdownView: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(parseMarkdownBlocks().enumerated()), id: \.offset) { _, block in
                switch block {
                case .text(let content):
                    if let attributedString = try? AttributedString(markdown: content) {
                        Text(attributedString)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(content)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

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
                    // Save any accumulated text
                    if !currentTextLines.isEmpty {
                        blocks.append(.text(currentTextLines.joined(separator: "\n")))
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
            blocks.append(.text(currentTextLines.joined(separator: "\n")))
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

        Here's a [link](https://example.com).

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

        ## Example

        ```swift
        let numbers = [1, 2, 3, 4, 5]
        for number in numbers {
            print(number)
        }
        ```

        You can also use ***bold italic*** text.
        """)
        .padding()
    }
}
