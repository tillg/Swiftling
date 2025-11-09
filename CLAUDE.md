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

## UI Architecture

### Navigation Pattern: NavigationSplitView with Environment-Based State

The app uses modern SwiftUI navigation patterns (iOS 16+) with the following architecture:

**Three-Column Layout:**
1. **Sidebar**: Knowledge source selection and search interface
2. **Results List**: Search results displayed as cards
3. **Detail View**: Full documentation content with metadata

**State Management:**
- Centralized `AppState` class marked `@Observable` (iOS 17+)
- Single source of truth for: search query, results, selected result, enabled sources
- No prop drilling - state injected via `@Environment(AppState.self)`

**Key Implementation Pattern:**

```swift
@Observable
class AppState {
    var enabledSources: Set<String> = ["apple-docs"]
    var currentQuery: String = ""
    var searchResults: [SearchResult] = []
    var selectedResult: SearchResult?
    var isSearching: Bool = false
    var searchError: Error?

    func performSearch(query: String) async {
        // Search logic using KnowledgeRetriever
    }
}

struct ContentView: View {
    @State private var appState = AppState()

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .environment(appState)
        } content: {
            ResultsListView()
                .environment(appState)
        } detail: {
            if let result = appState.selectedResult {
                DetailView(result: result)
                    .environment(appState)
            }
        }
    }
}
```

**Navigation Principles:**
- Use NavigationSplitView for multi-column layouts (not NavigationStack)
- Selection-based navigation via `selection:` binding (not path-based)
- All views access state via `@Environment` (no manual passing)
- `SearchResult` conforms to `Identifiable`, `Hashable`, and `Sendable`
- Platform adaptivity: Three columns on iPad/Mac, collapses to stack on iPhone

**UI States:**
- Loading state: Show progress indicator during search
- Error state: Display error with retry button
- Empty state: Show placeholder when no results
- Success state: Display result cards with breadcrumbs, tags, type badges

See `BASIC_UI.md` for detailed UI specifications and `SWIFTUI_NAVIGATION_BEST_PRACTICES.md` for navigation patterns.

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

**Completed:**
- ✅ KnowledgeRetriever protocol and architecture (see `KNOWLEDGE_RETRIEVER.md`)
- ✅ Apple Developer Documentation retriever implementation
  - HTML search result parsing with breadcrumbs, tags, and result types
  - JSON-to-Markdown conversion for documentation pages
  - In-memory caching system
  - Xcode playground tests for validation
- ✅ UI architecture specification (see `BASIC_UI.md`)
  - Three-column NavigationSplitView layout
  - Modern navigation patterns following iOS 16+ best practices
  - AppState-based state management with environment injection
  - Detailed mockups and implementation examples

**In Progress:**
- SwiftUI UI implementation
  - SidebarView (knowledge source selection + search)
  - ResultsListView (search results with cards)
  - DetailView (documentation content + metadata)
- AppState integration with KnowledgeRetriever

**Not Started:**
- Foundation Models integration for LLM-powered answers
- Tool protocol implementation for LLM integration
- HackingWithSwift knowledge retriever
- GitHub repositories knowledge retriever
- Deep linking support
- State restoration and search history
