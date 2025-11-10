//
//  MarkdownView.swift
//  Swiftling
//
//  Created by Claude Code on 09.11.25.
//

import SwiftUI
import MarkdownUI

/// A view that renders markdown using the MarkdownUI library
///
/// MarkdownUI provides full GitHub-flavored markdown support including:
/// - Headings (# through ######)
/// - Bold, italic, strikethrough
/// - Code blocks with syntax highlighting
/// - Lists (ordered and unordered)
/// - Block quotes
/// - Links and images
/// - Tables
struct MarkdownView: View {
    let markdown: String

    var body: some View {
        Markdown(markdown)
            .textSelection(.enabled)
    }
}

/// Full markdown view with proper heading rendering
///
/// This view wraps MarkdownView with full-width layout
struct FullMarkdownView: View {
    let markdown: String

    var body: some View {
        MarkdownView(markdown: markdown)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Markdown Features") {
    ScrollView {
        MarkdownView(markdown: """
        # Main Heading

        Here's a paragraph with **bold**, *italic*, and `inline code`.

        ## Subheading

        ### Lists

        - List item 1
        - List item 2
        - List item 3

        ### Code Blocks

        ```swift
        struct Example {
            let property: String
        }
        ```

        ### Links

        Visit [Apple Developer](https://developer.apple.com) for more info.
        """)
        .padding()
    }
}
