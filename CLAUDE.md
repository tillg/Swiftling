# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Swiftling is an iOS/macOS app that provides tailored help for Swift developers by answering questions based on reliable sources searched in real-time. The app leverages Apple's Foundation Models framework (on-device LLM) with custom Tools to search and retrieve documentation from:

- Apple Developer Documentation
- HackingWithSwift
- Selected & curated GitHub repos

The system runs entirely on-device for privacy, using Swift 6 concurrency patterns (async/await).

## Build Commands

Build and run using Xcode:
```bash
# Open the project
open Swiftling/Swiftling.xcodeproj

# Build from command line
xcodebuild -project Swiftling/Swiftling.xcodeproj -scheme Swiftling -configuration Debug build

# Run tests
xcodebuild test -project Swiftling/Swiftling.xcodeproj -scheme Swiftling

# Clean build folder
xcodebuild clean -project Swiftling/Swiftling.xcodeproj -scheme Swiftling
```

## Architecture

### Core Design Pattern: Search-and-Retrieval Tool Architecture

The architecture implements a **Tool-based retrieval system** integrated with Apple's Foundation Models framework. Key architectural components:

1. **Search Module**: Queries site-specific search APIs (no pre-crawling) with user questions
2. **Content Fetch & Conversion**: Retrieves relevant pages and converts to clean Markdown/text
3. **Foundation Model Tool Integration**: Swift classes conforming to Apple's `Tool` protocol that the on-device LLM can invoke
4. **Async Execution**: All network calls use Swift concurrency (async/await) to keep UI responsive

### Tool Pattern

Each content source (Apple Docs, GitHub, etc.) is implemented as a separate Tool:

```swift
struct AppleDocsTool: Tool {
    let name = "appleDocsSearch"
    let description = "Search Apple Developer Docs and return the top result in markdown."

    func call(arguments: Input) async throws -> ToolOutput {
        // 1. Query site's search API
        // 2. Fetch top result(s)
        // 3. Convert to Markdown
        // 4. Return as ToolOutput
    }
}
```

Tools are registered with the LanguageModelSession and the LLM autonomously decides when to invoke them based on user queries.

### Apple Documentation Conversion (Sosumi-like Approach)

Apple's docs require JavaScript to render. The architecture works around this by:
- Identifying the underlying JSON data source for each documentation page
- Fetching the JSON directly (bypassing JS requirements)
- Converting JSON to clean Markdown with preserved code blocks, API signatures, etc.

This mimics the sosumi.ai approach and ensures AI-readable documentation content.

### Privacy & Performance

- **Privacy by design**: LLM inference runs entirely on-device using Apple's Foundation Models (3B-parameter model). Only direct queries to documentation sites are made.
- **Non-blocking UI**: All network calls use async/await to prevent UI jank. SwiftUI views remain responsive during searches.
- **Streaming**: Leverage Foundation Models' token-streaming for progressive answer display.
- **Caching**: In-memory cache for frequently accessed pages to reduce latency.

### Extensibility

New content sources can be added by:
1. Creating a new Tool conforming to Apple's `Tool` protocol
2. Implementing site-specific search and fetch logic
3. Converting content to Markdown/text
4. Registering the tool with the LanguageModelSession

Consider using a shared `DocumentationSource` protocol for common search/fetch patterns across tools.

## Development Context

- **Language**: Swift 6
- **UI Framework**: SwiftUI
- **Concurrency**: Structured concurrency with async/await
- **Target Platforms**: iOS 26+, macOS (requires Foundation Models framework)
- **Key Dependencies**: Apple's Foundation Models framework for on-device LLM and Tool support

## Key Implementation Notes

- When implementing Tools, use URLSession with async/await for all network calls
- Tool `call` methods should handle failures gracefully (network timeouts, no results) and return user-friendly messages
- Register multiple Tools with the LanguageModelSession using `LanguageModelSession(tools: [...])`
- Reinforce tool usage in system prompts (e.g., "If the user asks about Apple APIs, use appleDocsSearch")
- Use `@Generable` on Tool input structs for easier model argument generation
- All HTML-to-Markdown conversion should strip scripts/boilerplate and preserve code blocks
- Respect site ToS by using official search APIs rather than scraping

## Current Status

Project is in initial planning/setup phase with basic SwiftUI app structure. The detailed architecture document (SEARCHER.md) outlines the complete implementation plan for the search-and-retrieval system.
