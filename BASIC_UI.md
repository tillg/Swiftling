# BASIC_UI.md

How could a basic UI for this App look like?

## Requirements

- Should work on iPad and macOS, also iOS (even though the content might be a bit heavy for the small screen).
- The user can select which "Knowledge Sources" to use - currently there's only "Apple Docs"
- When asking a question, the results are listed as "List" of "ResultListView"s
- When clicking on a ResultListView we get a larger ResultView that has meta data at the top and the content in the main part.
- The content is rendered as formatted Markdown
- In the meta data the URL is a clickable URL.

---

## UI Design Proposal

### Overall Layout Architecture

Use a **NavigationSplitView** with three columns (adaptive to platform):

1. **Sidebar (Column 1)**: Knowledge source selection & search history
2. **Results List (Column 2)**: Search results for current query
3. **Detail View (Column 3)**: Full documentation content with metadata

**Responsive Behavior**:
- **macOS/iPad landscape**: Show all three columns simultaneously
- **iPad portrait**: Show sidebar + one main column (results or detail)
- **iPhone**: Show one column at a time with navigation stack

**Navigation Architecture** (following iOS 16+ best practices):

Based on modern SwiftUI navigation patterns, we'll use:
- **NavigationSplitView** for the multi-column layout (iPad/Mac)
- **Explicit state management** with `@State` for selections
- **Environment injection** for navigation actions in nested views
- **Hashable route models** for type-safe navigation

```swift
// MARK: - Navigation Model (State Layer)
enum SearchDestination: Hashable, Identifiable {
    case result(SearchResult)

    var id: String {
        switch self {
        case .result(let result):
            return result.id.uuidString
        }
    }
}

// MARK: - App State
@Observable
class AppState {
    var enabledSources: Set<String> = ["apple-docs"]
    var currentQuery: String = ""
    var searchResults: [SearchResult] = []
    var selectedResult: SearchResult?
    var isSearching: Bool = false
    var searchError: Error?
}

// MARK: - Main App View
struct ContentView: View {
    @State private var appState = AppState()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar (Column 1)
            SidebarView()
                .environment(appState)

        } content: {
            // Results List (Column 2)
            ResultsListView()
                .environment(appState)

        } detail: {
            // Detail View (Column 3)
            if let selectedResult = appState.selectedResult {
                DetailView(result: selectedResult)
                    .environment(appState)
            } else {
                PlaceholderView()
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}
```

**Key Architecture Decisions**:

1. **State Management**: Use `@Observable` (iOS 17+) or `@StateObject` (iOS 14+) for centralized app state
2. **Selection Binding**: NavigationSplitView handles selection naturally without manual path management
3. **Environment Injection**: Pass `appState` down via `.environment()` to avoid prop drilling
4. **Type Safety**: `SearchResult` conforms to `Identifiable` and `Hashable` for selection tracking
5. **Separation of Concerns**: Views don't manage navigation state, they read from environment

---

### 1. Sidebar (Column 1)

**Top Section - Knowledge Sources**

```
┌─────────────────────────────┐
│ 📚 Knowledge Sources        │
├─────────────────────────────┤
│ ☑ Apple Developer Docs      │
│ ☐ HackingWithSwift          │ [disabled/coming soon]
│ ☐ GitHub Repositories       │ [disabled/coming soon]
└─────────────────────────────┘
```

**Middle Section - Search Interface**

```
┌─────────────────────────────┐
│ 🔍 [Search field]           │
│    "Ask a question..."      │
│                     [Go] 🚀 │
└─────────────────────────────┘
```

**Bottom Section - Recent Searches** (optional, for v2)

```
┌─────────────────────────────┐
│ 📝 Recent Searches          │
├─────────────────────────────┤
│ • URLSession basics         │
│ • Array methods             │
│ • SwiftUI state management  │
└─────────────────────────────┘
```

**Implementation** (following navigation best practices):

```swift
struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText: String = ""

    var body: some View {
        List {
            Section("Knowledge Sources") {
                Toggle("Apple Developer Docs", isOn: binding(for: "apple-docs"))
                Toggle("HackingWithSwift", isOn: .constant(false))
                    .disabled(true)
                    .foregroundStyle(.secondary)
                Toggle("GitHub Repositories", isOn: .constant(false))
                    .disabled(true)
                    .foregroundStyle(.secondary)
            }

            Section("Search") {
                HStack {
                    TextField("Ask a question...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            performSearch()
                        }

                    Button(action: performSearch) {
                        Label("Go", systemImage: "arrow.right.circle.fill")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("Swiftling")
    }

    private func binding(for source: String) -> Binding<Bool> {
        Binding(
            get: { appState.enabledSources.contains(source) },
            set: { enabled in
                if enabled {
                    appState.enabledSources.insert(source)
                } else {
                    appState.enabledSources.remove(source)
                }
            }
        )
    }

    private func performSearch() {
        guard !searchText.isEmpty else { return }
        appState.currentQuery = searchText
        Task {
            await appState.performSearch(query: searchText)
        }
    }
}
```

**Design Details**:

- Use `@Environment` to access app state (no prop drilling)
- Search triggers via Enter key (`.onSubmit`) or button tap
- Knowledge source toggles bind directly to `enabledSources` Set
- Async search operations handled with Swift concurrency
- Disabled sources shown with `.disabled(true)` + gray color

---

### 2. Results List (Column 2)

Shows search results as compact cards. Each `ResultListView` displays:

```
┌────────────────────────────────────────┐
│ 🔷 URLSession                          │
│    Foundation > Networking             │ [breadcrumbs]
│    📄 documentation                     │ [type badge]
│                                        │
│    Create and configure network        │ [summary]
│    requests for your app...            │
│                                        │
│    🏷 networking, http, api            │ [tags]
└────────────────────────────────────────┘
```

**Visual Structure** (per result):
```swift
VStack(alignment: .leading, spacing: 8) {
  // Title
  HStack {
    Image(systemName: sourceIcon)  // 🔷 = Apple Docs
    Text(result.title)
      .font(.headline)
  }

  // Breadcrumbs
  if !breadcrumbs.isEmpty {
    Text(breadcrumbs.joined(separator: " > "))
      .font(.caption)
      .foregroundStyle(.secondary)
  }

  // Result Type Badge
  if let type = result.resultType {
    HStack {
      Image(systemName: typeIcon(for: type))
      Text(type)
    }
    .font(.caption)
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(.quaternary)
    .clipShape(Capsule())
  }

  // Summary
  if let summary = result.summary {
    Text(summary)
      .font(.subheadline)
      .foregroundStyle(.secondary)
      .lineLimit(3)
  }

  // Tags
  if !tags.isEmpty {
    HStack(spacing: 4) {
      Image(systemName: "tag")
        .font(.caption2)
      Text(tags.joined(separator: ", "))
        .font(.caption)
    }
    .foregroundStyle(.tertiary)
  }
}
.padding()
.background(.background)
.cornerRadius(8)
.shadow(radius: 2)
```

**Implementation** (with environment-based navigation):

```swift
struct ResultsListView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.isSearching {
                LoadingView(message: "Searching \(sourceNames)...")
            } else if let error = appState.searchError {
                ErrorView(error: error) {
                    // Retry action
                    Task {
                        await appState.performSearch(query: appState.currentQuery)
                    }
                }
            } else if appState.searchResults.isEmpty && !appState.currentQuery.isEmpty {
                EmptyStateView()
            } else {
                resultsList
            }
        }
        .navigationTitle("Results")
    }

    private var resultsList: some View {
        List(appState.searchResults, selection: $appState.selectedResult) { result in
            ResultListView(result: result)
                .tag(result)
        }
    }

    private var sourceNames: String {
        appState.enabledSources
            .map { $0.replacingOccurrences(of: "-", with: " ").capitalized }
            .joined(separator: ", ")
    }
}

struct ResultListView: View {
    let result: SearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            HStack {
                Image(systemName: sourceIcon(for: result.sourceIdentifier))
                Text(result.title)
                    .font(.headline)
            }

            // Breadcrumbs
            if !result.breadcrumbs.isEmpty {
                Text(result.breadcrumbs.joined(separator: " > "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Result Type Badge
            if let type = result.resultType {
                HStack {
                    Image(systemName: typeIcon(for: type))
                    Text(type)
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary)
                .clipShape(Capsule())
            }

            // Summary
            if let summary = result.summary {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            // Tags
            if !result.tags.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "tag")
                        .font(.caption2)
                    Text(result.tags.joined(separator: ", "))
                        .font(.caption)
                }
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private func sourceIcon(for source: String) -> String {
        switch source {
        case "apple-docs": return "apple.logo"
        case "hacking-with-swift": return "swift"
        case "github": return "chevron.left.forwardslash.chevron.right"
        default: return "doc.text"
        }
    }

    private func typeIcon(for type: String) -> String {
        switch type.lowercased() {
        case "documentation": return "doc.text"
        case "sample-code": return "chevron.left.forwardslash.chevron.right"
        case "video": return "play.rectangle"
        default: return "doc"
        }
    }
}
```

**List Behavior**:

- List uses `selection:` binding to automatically manage selected result
- Selection flows through `@Environment` AppState (no prop drilling)
- Loading/error/empty states handled at the list level
- Each result card is tappable and highlights when selected
- No manual navigation code in ResultListView (declarative selection only)

---

### 3. Detail View (Column 3)

**Header Section - Metadata Card**
```
┌────────────────────────────────────────────────┐
│ URLSession                                     │
│ Foundation > Networking > URLSession           │
│                                                │
│ 📄 documentation                               │
│ 🔗 developer.apple.com/documentation/...      │ [clickable]
│ 🏷 networking, http, api, async                │
│                                                │
│ Source: Apple Developer Documentation          │
│ Last fetched: 2 minutes ago                    │
└────────────────────────────────────────────────┘
```

**Content Section - Markdown Rendering**
```
┌────────────────────────────────────────────────┐
│                                                │
│ [Rendered Markdown Content]                    │
│                                                │
│ # Overview                                     │
│ The URLSession class provides...              │
│                                                │
│ ## Creating a Session                          │
│ To create a URLSession instance:              │
│                                                │
│ ```swift                                       │
│ let session = URLSession.shared               │
│ ```                                            │
│                                                │
│ ...                                            │
│                                                │
└────────────────────────────────────────────────┘
```

**Implementation Details**:

```swift
ScrollView {
  VStack(alignment: .leading, spacing: 20) {
    // Metadata Card
    VStack(alignment: .leading, spacing: 12) {
      // Title
      Text(result.title)
        .font(.largeTitle)
        .fontWeight(.bold)

      // Breadcrumbs
      Text(breadcrumbs.joined(separator: " > "))
        .font(.subheadline)
        .foregroundStyle(.secondary)

      Divider()

      // Type
      Label(result.resultType ?? "documentation",
            systemImage: typeIcon)
        .font(.subheadline)

      // URL (clickable)
      Link(destination: result.url) {
        HStack {
          Image(systemName: "link")
          Text(result.url.absoluteString)
            .lineLimit(1)
        }
        .font(.subheadline)
        .foregroundStyle(.blue)
      }

      // Tags
      if !result.tags.isEmpty {
        FlowLayout {  // Custom view for wrapping tags
          ForEach(result.tags, id: \.self) { tag in
            Text(tag)
              .font(.caption)
              .padding(.horizontal, 10)
              .padding(.vertical, 5)
              .background(.blue.opacity(0.1))
              .foregroundStyle(.blue)
              .clipShape(Capsule())
          }
        }
      }

      Divider()

      // Fetch metadata
      HStack {
        Text("Source: \(source.sourceName)")
        Spacer()
        Text("Fetched: \(formatRelativeTime(fetchedAt))")
      }
      .font(.caption)
      .foregroundStyle(.tertiary)
    }
    .padding()
    .background(.quaternary.opacity(0.3))
    .cornerRadius(12)

    // Markdown Content
    MarkdownView(markdown: content.markdown)
      .padding(.horizontal)
  }
  .padding()
}
```

**Markdown Rendering**:
- Use a Markdown rendering library that supports:
  - Headers (H1-H6)
  - Code blocks with syntax highlighting (Swift, JSON, etc.)
  - Inline code
  - Links (all clickable)
  - Lists (ordered and unordered)
  - Bold, italic, strikethrough
  - Blockquotes
- Suggested libraries:
  - [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui)
  - Or Apple's native `Text(.init(markdown:))` for basic rendering

---

### 4. UI States

**Loading State**
```
┌────────────────────────────────┐
│                                │
│       ⏳ Searching...          │
│                                │
│  Querying Apple Developer Docs │
│                                │
└────────────────────────────────┘
```
Use: `ProgressView()` with descriptive text

**Empty State (No Results)**
```
┌────────────────────────────────┐
│                                │
│       🔍                       │
│   No results found             │
│                                │
│   Try a different search term  │
│   or enable more sources       │
│                                │
└────────────────────────────────┘
```

**Error State**
```
┌────────────────────────────────┐
│                                │
│       ⚠️                       │
│   Search failed                │
│                                │
│   Network error: Connection    │
│   timed out                    │
│                                │
│   [Try Again]                  │
│                                │
└────────────────────────────────┘
```

**Placeholder State (No Search Yet)**
```
┌────────────────────────────────┐
│                                │
│       💡                       │
│   Start by asking a question   │
│                                │
│   Try: "How to use URLSession?" │
│   or "SwiftUI state management" │
│                                │
└────────────────────────────────┘
```

---

### 5. Platform-Specific Adaptations

**macOS**:
- Window minimum size: 900x600
- Use system font sizes (adapt to user's system settings)
- Support keyboard shortcuts:
  - `Cmd+F`: Focus search field
  - `Cmd+K`: Focus search field (alternative)
  - `Cmd+1/2/3`: Jump between columns
  - `Cmd+[/]`: Navigate back/forward through results
  - `Cmd+R`: Refresh/re-fetch current result
- Native macOS toolbar with search and source selection
- Support drag-and-drop URL from detail view to other apps

**iPad**:
- Support slide-over and split-view multitasking
- Toolbar with search and filter buttons
- Swipe gestures for navigation
- Support Apple Pencil for scrolling/selecting
- Dynamic Type support (respect user font size preferences)

**iPhone**:
- Full-screen navigation stack
- Search bar in navigation bar or as toolbar
- Floating action button for search (optional)
- Pull-to-refresh on results list
- Compact result cards (less metadata visible)
- Share sheet integration for results

---

### 6. Color Scheme & Theming

**Light Mode**:
- Background: `.background` (system white/gray)
- Cards: `.secondaryBackground` with subtle shadow
- Accent: `.accentColor` (blue) for links, selections
- Text: `.primary` for body, `.secondary` for metadata

**Dark Mode**:
- Background: `.background` (system black/dark gray)
- Cards: `.secondaryBackground` (lighter dark gray)
- Accent: `.accentColor` (lighter blue) for visibility
- Text: `.primary` (white), `.secondary` (gray)

Both automatically handled by SwiftUI semantic colors.

---

### 7. Accessibility

- All interactive elements have accessibility labels
- Support VoiceOver with proper hints
- Dynamic Type support (respect user text size)
- High contrast mode support
- Keyboard navigation (macOS)
- Voice Control support (iOS)
- Reduce Motion support (minimize animations)

---

### 8. Example View Hierarchy

```
App (SwiftlingApp.swift)
├─ NavigationSplitView
│  ├─ Sidebar
│  │  ├─ KnowledgeSourcePicker
│  │  │  └─ List with Toggles
│  │  ├─ SearchField
│  │  └─ RecentSearches (optional)
│  │
│  ├─ ResultsList
│  │  ├─ if searching: ProgressView
│  │  ├─ if error: ErrorView
│  │  ├─ if empty: EmptyStateView
│  │  └─ else: List<ResultListView>
│  │     └─ ForEach(results) { result in
│  │        ResultListView(result)
│  │     }
│  │
│  └─ DetailView
│     ├─ if no selection: PlaceholderView
│     ├─ if loading: ProgressView
│     └─ else: ScrollView
│        ├─ MetadataCard
│        └─ MarkdownView
```

---

### 9. Implementation Phases

**Phase 1 - MVP** (Current):
- Basic three-column layout
- Apple Docs source only
- Simple search with results list
- Basic metadata + markdown rendering
- Manual search (no auto-complete)

**Phase 2 - Enhanced**:
- Search suggestions as you type
- Recent searches history
- Multiple knowledge sources (HackingWithSwift, GitHub)
- Favorites/bookmarks
- Share functionality

**Phase 3 - Advanced**:
- Offline caching with persistence
- Search filters (type, tags, source)
- Compare multiple results side-by-side
- Export results to PDF/Markdown
- AI-powered answer synthesis (using Foundation Models)

---

## Visual Mockup (ASCII Art)

### macOS/iPad Landscape (Full Width)

```
┌──────────────┬──────────────────────┬─────────────────────────────────┐
│              │                      │ URLSession                      │
│ 📚 Sources   │ 🔷 URLSession        │ Foundation > Networking         │
│ ☑ Apple      │ Foundation > Net...  │                                 │
│ ☐ H.w.Swift  │ 📄 documentation     │ 📄 documentation                │
│ ☐ GitHub     │ Create network...    │ 🔗 developer.apple.com/...      │
│              │ 🏷 networking, http  │ 🏷 networking, http, api        │
│ 🔍 [Search]  │                      │ Source: Apple Developer Docs    │
│              │──────────────────────│─────────────────────────────────│
│              │ 🔷 URL                │                                 │
│              │ Foundation > URL     │ # Overview                      │
│              │ 📄 documentation     │                                 │
│              │ A value that...      │ The URLSession class provides   │
│              │ 🏷 networking, url   │ an API for downloading content  │
│              │                      │ from web services...            │
│              │──────────────────────│                                 │
│              │ 🔷 Task              │ ## Creating a Session           │
│              │ Swift > Concurrency  │                                 │
│              │ 📄 documentation     │ To create a URLSession:         │
│              │ A unit of...         │                                 │
│              │ 🏷 async, await      │ ```swift                        │
│ 📝 Recent    │                      │ let session = URLSession.shared │
│ • URLSession │──────────────────────│ ```                             │
│ • Array      │ 🔷 Codable           │                                 │
│ • SwiftUI    │ Swift > Encoding     │ ...                             │
│              │ 📄 protocol          │                                 │
│              │ Types that can...    │                                 │
└──────────────┴──────────────────────┴─────────────────────────────────┘
```

### iPhone (Single Column View)

**Step 1: Sidebar/Search**
```
┌─────────────────────┐
│ 📚 Knowledge Sources│
│ ☑ Apple Developer   │
│ ☐ HackingWithSwift  │
│ ☐ GitHub Repos      │
│                     │
│ 🔍 [Search field]   │
│                     │
│ 📝 Recent Searches  │
│ • URLSession basics │
│ • Array methods     │
└─────────────────────┘
```

**Step 2: Results List** (after search)
```
┌─────────────────────┐
│ < Back   10 results │
├─────────────────────┤
│ 🔷 URLSession       │
│ Foundation > Net... │
│ 📄 documentation    │
│ Create network...   │
├─────────────────────┤
│ 🔷 URL              │
│ Foundation > URL    │
│ 📄 documentation    │
│ A value that...     │
├─────────────────────┤
│ 🔷 Task             │
│ Swift > Concurrency │
│ 📄 documentation    │
│ A unit of async...  │
└─────────────────────┘
```

**Step 3: Detail View** (after tap)
```
┌─────────────────────┐
│ < Results           │
├─────────────────────┤
│ URLSession          │
│ Foundation > Net... │
│                     │
│ 📄 documentation    │
│ 🔗 developer.apple..│
│ 🏷 networking, http │
│                     │
│ Source: Apple Dev   │
├─────────────────────┤
│                     │
│ # Overview          │
│                     │
│ The URLSession class│
│ provides an API for │
│ downloading...      │
│                     │
│ ## Creating Session │
│                     │
│ ```swift            │
│ let session = ...   │
│ ```                 │
│                     │
└─────────────────────┘
```

---

## Navigation Architecture Review

### Alignment with Modern SwiftUI Best Practices

This UI design follows iOS 16+ navigation patterns as outlined in the best practices document:

**✅ What We're Doing Right:**

1. **Explicit State Management**
   - Single source of truth: `AppState` manages all navigation and search state
   - No hidden state or implicit transitions
   - State is `@Observable` (iOS 17+) for automatic change tracking

2. **Environment-Based Navigation**
   - `@Environment(AppState.self)` injected into all views
   - No prop drilling through multiple view layers
   - Child views can read/modify state without manual passing

3. **Type-Safe Selection**
   - `SearchResult` conforms to `Identifiable` and `Hashable`
   - NavigationSplitView uses `selection:` binding for type safety
   - No string-based routing or manual path management

4. **Separation of Concerns**
   - Navigation Model (State Layer): `AppState`, `SearchResult`
   - Presentation Layer: `ContentView`, NavigationSplitView structure
   - Feature Layer: `SidebarView`, `ResultsListView`, `DetailView` are standalone

5. **Async-First Design**
   - Search operations use Swift concurrency (`async/await`)
   - UI remains responsive during network calls
   - Loading states properly communicated to user

**🎯 Key Differences from Traditional Patterns:**

1. **NavigationSplitView vs. NavigationStack**
   - We use NavigationSplitView because we have a multi-column master-detail layout
   - NavigationStack is better for linear flows (onboarding, checkout, etc.)
   - Our pattern: Sidebar → Results → Detail (three distinct columns)

2. **Selection-Based vs. Path-Based Navigation**
   - NavigationSplitView uses `selection:` binding (simpler for our use case)
   - NavigationStack uses `path:` array for stack-based navigation
   - Our flow doesn't need a navigation stack history (just current selection)

3. **No Route Enum (for now)**
   - The best practices suggest an `AppRoute` enum for NavigationStack
   - We don't need it because NavigationSplitView handles selection naturally
   - If we add modal sheets or stack navigation later, we'd introduce routes

**🔮 Future Considerations:**

1. **Deep Linking**
   - Currently not implemented
   - Would require: URL scheme handling → Parse URL → Set `selectedResult` in AppState
   - Example: `swiftling://search?query=URLSession&resultId=<uuid>`

2. **State Restoration**
   - Save search history and last selected result
   - Restore on app launch using `@SceneStorage` or persistent storage
   - Prepopulate `appState.searchResults` and `appState.selectedResult`

3. **Modal Navigation**
   - If we add settings, filters, or help screens (modals)
   - Introduce `enum AppSheet: Identifiable` for sheet presentation
   - Bind to `@State var presentedSheet: AppSheet?`

**📱 Platform-Specific Adaptations:**

- **macOS/iPad**: Three columns visible simultaneously (current design)
- **iPhone**: NavigationSplitView automatically collapses to navigation stack
- **No code changes needed** - SwiftUI handles responsive behavior

**🧪 Testability:**

Our architecture is highly testable:

```swift
// Test search state updates
@Test func testSearchUpdatesResults() async {
    let appState = AppState()
    await appState.performSearch(query: "URLSession")
    #expect(!appState.searchResults.isEmpty)
}

// Test selection
@Test func testResultSelection() {
    let appState = AppState()
    let result = SearchResult(...)
    appState.selectedResult = result
    #expect(appState.selectedResult?.id == result.id)
}

// Test source toggling
@Test func testSourceToggle() {
    let appState = AppState()
    appState.enabledSources.insert("github")
    #expect(appState.enabledSources.contains("github"))
}
```

All navigation logic is in `AppState`, which is testable without rendering UI.

---

## Implementation Checklist

Before starting implementation, ensure:

- [ ] `SearchResult` conforms to `Identifiable`, `Hashable`, and `Sendable`
- [ ] `AppState` is marked `@Observable` (iOS 17+) or uses `ObservableObject` (iOS 14-16)
- [ ] All async operations use proper Task handling with error propagation
- [ ] Loading/error/empty states are clearly communicated
- [ ] All views use `@Environment` instead of passing state as parameters
- [ ] Minimum deployment target is iOS 16+ (for NavigationSplitView)
- [ ] Consider fallback UI for iPhone (test three-column → stack collapse)
