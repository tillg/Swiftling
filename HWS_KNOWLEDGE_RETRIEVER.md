# Hacking With Swift Knowledge Retriever

A Knowledge retriever for hackingwithswift.com.

Uses the search at hackingwithswift.com. When looking at it in the web inspector:

```text
Summary
URL: https://www.hackingwithswift.com/search/what%20is%20a%20protocol
Status: 200
Source: Network
Address: 172.67.71.244:443

Request
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
Accept-Encoding: gzip, deflate, br
Accept-Language: en-GB,en;q=0.9
Cookie: PHPSESSID=jfebbmobjjbtj75bgsgqohanot
Priority: u=0, i
Referer: https://www.hackingwithswift.com/search/what%20is%20a%20protocol
Sec-Fetch-Dest: document
Sec-Fetch-Mode: navigate
Sec-Fetch-Site: same-origin
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.1 Safari/605.1.15

Response
Alt-Svc: h3=":443"; ma=86400
Cache-Control: no-store, no-cache, must-revalidate
cf-cache-status: DYNAMIC
cf-ray: 99be875eaa4084fa-HKG
Content-Encoding: gzip
Content-Length: 26132
Content-Type: text/html; charset=UTF-8
Date: Sun, 09 Nov 2025 16:01:27 GMT
Expires: Thu, 19 Nov 1981 08:52:00 GMT
nel: {"report_to":"cf-nel","success_fraction":0.0,"max_age":604800}
Pragma: no-cache
Priority: u=0,i
Report-To: {"group":"cf-nel","max_age":604800,"endpoints":[{"url":"https://a.nel.cloudflare.com/report/v4?s=EBXahNzogQiRLGwBvjEb%2FFq%2Be4%2BytrldpyJktnhSvS3j6TIkqWlXfZdHOAFAUpXSyT98L5EJhuho%2Fd4W8vmM%2FmIq%2FOQMe0aUfRSE4at5G3EBCfMduaRf"}]}
Server: cloudflare
Server-Timing: cfExtPri
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
Vary: Accept-Encoding
X-Content-Type-Options: nosniff
X-Frame-Options: SAMEORIGIN
```

When retrieving a page, uses the markdownify & cleanup logic of https://github.com/tillg/site2chunks with the cleanup configuration of https://github.com/tillg/site2chunks/blob/main/config/hackingwithswift/config.yaml

```yaml
  # Cleaning rules
  rules:
    # Remove navigation menu (appears at top of every page)
    - type: section_boundary
      description: "Navigation menu"
      start_marker: "- [Forums](/forums)"
      end_marker: "- [SUBSCRIBE](/plus)"
      inclusive: true

    # Remove promotional book banner (appears after nav on some pages)
    - type: exact_match
      description: "Book promotional banner"
      pattern: "[NEW BOOK: **Code got you started. This gets you *paid*.** >>](/store/everything-but-the-code)"
      max_remove: -1

    # Remove sponsored content blocks
    - type: regex
      description: "Sponsored content blocks"
      pattern: '\*\*SPONSORED\*\*[^\n]*\n\n\[[^\]]+\]\([^\)]+\)\n'
      flags: [MULTILINE]

    # Remove footer sections starting with store link
    - type: section_boundary
      description: "Footer content and social links"
      start_marker: "[Click here to visit the Hacking with Swift store >>](/store)"
      end_marker: "Link copied to your pasteboard."
      inclusive: true

    # Alternative footer pattern (some pages have different footer)
    - type: section_boundary
      description: "Alternative footer starting with Back to..."
      start_marker: "[Back to 100 Days of Swift](/100)"
      end_marker: "Link copied to your pasteboard."
      inclusive: true

    # Alternative footer starting with social media links (empty H4 headers)
    - type: regex
      description: "Footer with social media links and legal text"
      pattern: '\[####\s*\n\nTwitter\]\(https://twitter\.com/twostraws\).*?Hacking with Swift is ©\d{4} \[Hudson Heavy Industries\]\(https://www\.hudson\.uk\)\.'
      flags: [MULTILINE, DOTALL]

    # Remove "Need help?" CTAs
    - type: line_pattern
      description: "Need help tweet prompts"
      pattern: '^Need help\? Tweet me \[@twostraws\]'

    # Remove login status messages
    - type: exact_match
      description: "Login status messages"
      pattern: "You are not logged in"
      max_remove: -1

    - type: exact_match
      description: "Login prompts"
      pattern: "[Log in or create account](/login)"
      max_remove: -1

    - type: exact_match
      description: "Pasteboard messages"
      pattern: "Link copied to your pasteboard."
      max_remove: -1

    # Remove empty header markers (social media section markers and standalone H2)
    - type: line_pattern
      description: "Empty H4 header markers"
      pattern: '^####\s*$'

    - type: regex
      description: "Empty H2 header markers with surrounding blanks"
      pattern: '\n##\s*\n\n'
      flags: [MULTILINE]

    # Remove "Back to X" navigation links that appear mid-content
    - type: regex
      description: "Back navigation links"
      pattern: '\[Back to [^\]]+\]\([^\)]+\)'
      flags: [MULTILINE]

    # Remove RSS feed links
    - type: line_pattern
      description: "RSS feed links"
      pattern: '\[Subscribe to our RSS feed\]'

    # Remove newsletter subscription headings
    - type: regex
      description: "Newsletter subscription sections"
      pattern: '### Subscribe to my monthly newsletter\n\nGet a free book delivered.*?\n\nSubscribe'
      flags: [MULTILINE, DOTALL]

    # Remove Slack join sections
    - type: regex
      description: "Slack community sections"
      pattern: '### Join us on Slack!.*?\[JOIN HERE\]\(/slack\)'
      flags: [MULTILINE, DOTALL]

    # Remove "Get the app" promotional sections
    - type: regex
      description: "App download promotional sections"
      pattern: '### Get the app!.*?with Unwrap:.*?completely free with no in-app purchases!'
      flags: [MULTILINE, DOTALL]

    # Clean up "About Me" sections in footer
    - type: regex
      description: "About Me footer sections"
      pattern: '## About Me\n\nMy name is Paul Hudson.*?Want to know more about me\? Click here.*?\]\.'
      flags: [MULTILINE, DOTALL]

    # Remove article category tags
    - type: regex
      description: "Article category tags"
      pattern: '^######\s+\[[A-Z\s]+\]\(/articles/category/[^\)]+\)'
      flags: [MULTILINE]

    # Remove "Read Full Article" links
    - type: line_pattern
      description: "Read full article links"
      pattern: '^\[Read Full Article\]'

    # Remove "Continue reading" links
    - type: line_pattern
      description: "Continue reading links"
      pattern: '^\[Continue reading'

    # Remove "Read more" links
    - type: line_pattern
      description: "Read more links"
      pattern: '^\[Read more'

    # Remove "Older Posts" navigation
    - type: line_pattern
      description: "Older posts navigation"
      pattern: '^\[Older Posts\]'

    # Remove interview questions link
    - type: line_pattern
      description: "See full list of iOS interview questions link"
      pattern: '^\[See the full list of iOS interview questions\]'

    # Remove return to review menu link
    - type: line_pattern
      description: "Return to Review Menu navigation link"
      pattern: '^\[Return to Review Menu\]'

    # Remove standalone "Subscribe" text
    - type: line_pattern
      description: "Standalone Subscribe text"
      pattern: '^Subscribe$'

    # Remove feedback form sections
    - type: regex
      description: "Feedback/improvement form sections"
      pattern: 'How can this day be improved\?\n\nGreat job on finishing another day!.*?Thank you!'
      flags: [MULTILINE, DOTALL]

    # Remove "share your progress" social media prompts
    - type: regex
      description: "Share progress Twitter prompts"
      pattern: '## Now share your progress…\n\nIf you use Twitter.*?\[Tweet\]\(https://twitter.com/share\)'
      flags: [MULTILINE, DOTALL]

    # Remove page rating widgets
    - type: regex
      description: "Page usefulness rating widgets"
      pattern: 'Was this page useful\? Let us know!\n\n1\n2\n3\n4\n5\n\n(?:Average rating:.*?\n\n)?Thank you!'
      flags: [MULTILINE, DOTALL]

    # Remove "BUY OUR BOOKS" promotional headers
    - type: exact_match
      description: "Buy our books promotional text"
      pattern: "**BUY OUR BOOKS**"
      max_remove: -1

    # Remove forum reply blocks
    - type: regex
      description: "Forum reply to topic blocks"
      pattern: '### Reply to this topic…\n\nYou need to \[create an account or log in\]\(/login\?return=[^\)]+\) to reply\.\n\nAll interactions here are governed by our \[code of conduct\]\(/conduct\)\.'
      flags: [MULTILINE]

    # Remove "100 Days of Swift/SwiftUI" promotional blocks
    - type: regex
      description: "100 Days of Swift/SwiftUI promotional blocks"
      pattern: '## 100 Days of Swift(?:UI)?\n\n---\n\nThe 100 Days of Swift(?:UI)? is a free collection of videos, tutorials, tests, and more to help you learn Swift(?:UI)? faster\. \[Click here to learn more\]\(/100(?:/swiftui)?\), or watch the video below\.'
      flags: [MULTILINE]

    # Remove social sharing blocks with copy-paste text
    - type: section_boundary
      description: "Social sharing copy-paste blocks"
      start_marker: "Alternatively, copy and paste the text below to your preferred social network"
      end_marker: "via @twostraws"
      inclusive: true

    # Remove "Have some questions about..." chat prompts
    - type: regex
      description: "Have some questions chat prompts"
      pattern: '### Have some questions about .+?\?\n\nHit Send below to start a virtual conversation with me\.'
      flags: [MULTILINE]

    # Remove "Found X articles in the Swift Knowledge Base" headers
    - type: regex
      description: "Swift Knowledge Base article count headers"
      pattern: '### Found \d+ articles? in the \[Swift Knowledge Base\]\(/example-code\) for this category\.'
      flags: [MULTILINE]

    # Remove "About the Swift Knowledge Base" sections
    - type: section_boundary
      description: "About the Swift Knowledge Base promotional sections"
      start_marker: "### About the Swift Knowledge Base"
      end_marker: "Was this page useful? Let us know!"
      inclusive: true

    # Remove HWS+ "SELECT A CATEGORY" navigation section
    - type: regex
      description: "HWS+ SELECT A CATEGORY section"
      pattern: '^###### SELECT A CATEGORY\n\n(?:- \[(?:\*\*)?.+?(?:\*\*)?\]\(/plus/[^\)]+\)\n)+\n'
      flags: [MULTILINE]

    # Remove HWS+ "COURSES BY CATEGORY" navigation section
    - type: regex
      description: "HWS+ COURSES BY CATEGORY section"
      pattern: '^###### COURSES BY CATEGORY\n\n(?:- \[(?:\*\*)?.+?(?:\*\*)?\]\(/plus/[^\)]+\)\n)+\n'
      flags: [MULTILINE]

    # Remove HWS+ membership promotional sections
    - type: section_boundary
      description: "HWS+ membership features promotion"
      start_marker: "## Hacking with Swift+ membership includes…"
      end_marker: "#### A free ticket to Unwrap Live every year"
      inclusive: true

    # Remove article listings at end of article pages
    - type: regex
      description: "Related articles listing section"
      pattern: '\[More articles\]\(/articles\).*'
      flags: [MULTILINE, DOTALL]

    # Remove interactive quiz UI elements
    - type: regex
      description: "Interactive quiz UI elements"
      pattern: '^(?:True|False|Choose Option \d+)\n(?:(?:True|False|Choose Option \d+)\n)+\nCorrect!.*?\n\nOops.*?\n\nContinue$'
      flags: [MULTILINE, DOTALL]

    # Remove Swift version playground download and browse links
    - type: regex
      description: "Swift version playground download and navigation links"
      pattern: '^\[Download all Swift [\d.]+ changes as a playground\]\(/files/playgrounds/swift/playground[^\)]+\)\n \[Link to Swift [\d.]+ changes\]\(/swift/[\d.]+\)\n\n\[Browse changes in all Swift versions\]\(/swift\)$'
      flags: [MULTILINE]

    # Remove author bylines with social media links
    - type: regex
      description: "Author byline with social media"
      pattern: '^\[Paul Hudson\]\(/about\).*?@twostraws.*?$'
      flags: [MULTILINE]

    # Remove previous/next navigation tables (multi-row format with headers)
    - type: regex
      description: "Previous/next navigation tables"
      pattern: '^\|  \|  \|  \|\n\| --- \| --- \| --- \|\n\| \[<.*?\] \|  \| \[.*?>\] \|$'
      flags: [MULTILINE]

    # Remove single-row navigation tables
    - type: regex
      description: "Single-row previous/next/ToC navigation tables"
      pattern: '^\|\s\[<\s[^\]]+\]\([^\)]+\)\s\|\s{1,2}\|\s\[[^\]]+\]\([^\)]+\)\s\|$'
      flags: [MULTILINE]

    # Remove table of contents navigation rows
    - type: regex
      description: "Table of contents navigation row"
      pattern: '^\| \[Table of Contents\].*?\| \| \|$'
      flags: [MULTILINE]

    # Remove empty table structures
    - type: regex
      description: "Empty table rows"
      pattern: '^\|  \|  \|  \|\n\| --- \| --- \| --- \|$'
      flags: [MULTILINE]

    # Remove HWS+ subscription promotional text
    - type: regex
      description: "Subscription promotional text"
      pattern: 'If you don.t already subscribe, you can start a free trial.*?\.?$'
      flags: [MULTILINE, IGNORECASE]

    # Remove interview question "Important notes" section
    - type: section_boundary
      description: "Interview question boilerplate notes"
      start_marker: "## Important notes"
      end_marker: "## Related questions"
      inclusive: true

    # Remove interview question "Related questions" section
    - type: section_boundary
      description: "Related questions link list"
      start_marker: "## Related questions"
      end_marker: null
      inclusive: true

    # Remove "Review what you learned" boilerplate sections
    - type: section_boundary
      description: "Review section boilerplate explanations"
      start_marker: "## Review what you learned"
      end_marker: "## Challenge"
      inclusive: false

    # Remove "Watch me answer this question" video CTA links
    - type: line_pattern
      description: "Video CTA links"
      pattern: '^\[Watch me answer this question.*?\]\(/plus/.*?\)$'

    # Remove "Continue Reading >>" truncation teasers
    - type: regex
      description: "Continue reading teasers"
      pattern: '\.\.\.\s*\[Continue Reading >>?\]\(.*?\)$'
      flags: [MULTILINE]

    # Remove "Other changes in Swift X.X" lists
    - type: section_boundary
      description: "Other changes in Swift version lists"
      start_marker: "### Other changes in Swift"
      end_marker: null
      inclusive: true

    # Remove HWS+ membership badges from forum posts
    - type: regex
      description: "HWS+ membership badges"
      pattern: '\[HWS\+\]\(/plus ".*?"\)'
      flags: [MULTILINE]

    # Remove relative timestamps from forum posts
    - type: regex
      description: "Relative timestamps from forum posts"
      pattern: '\s+\d+[dhm]\s*$'
      flags: [MULTILINE]

    # Remove empty bullet points
    - type: line_pattern
      description: "Empty bullet points"
      pattern: '^-\s*$'

    # Clean up empty H2 headings left behind after content removal (run at end)
    - type: regex
      description: "Empty H2 headings cleanup (final pass)"
      pattern: '\n\n##\s*\n'
      flags: [MULTILINE]

```

---

## Architecture & Implementation Plan

### Overview

The HackingWithSwift knowledge retriever follows the same `KnowledgeRetriever` protocol pattern as the Apple Docs retriever, but with key differences in how content is sourced and processed:

- **Search**: HTML-based search interface (not JSON API)
- **Content**: HTML pages requiring conversion to markdown
- **Cleanup**: Extensive cleanup rules (~80) to remove navigation, promotional content, and UI elements

### Core Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      HWSRetriever                            │
│            (conforms to KnowledgeRetriever)                  │
│                                                              │
│  + search(query:maxResults:) -> [SearchResult]              │
│  + fetch(result:) -> DocumentContent                        │
└──────────────────┬───────────────────────┬──────────────────┘
                   │                       │
      ┌────────────▼────────────┐  ┌──────▼──────────────────┐
      │  HWSSearchResultParser  │  │  HWSContentFetcher      │
      │                         │  │                         │
      │  Parses HTML search     │  │  Fetches & converts     │
      │  results into           │  │  HTML pages to          │
      │  SearchResult objects   │  │  markdown               │
      └─────────────────────────┘  └──────┬──────────────────┘
                                           │
                         ┌─────────────────▼────────────────┐
                         │   HWSMarkdownCleaner             │
                         │                                  │
                         │  Applies 80+ cleanup rules       │
                         │  - section_boundary              │
                         │  - exact_match                   │
                         │  - regex                         │
                         │  - line_pattern                  │
                         └──────────────────────────────────┘
```

### Component Design

#### 1. HWSRetriever

**Responsibility**: Main entry point conforming to `KnowledgeRetriever` protocol

```swift
actor HWSRetriever: KnowledgeRetriever {
    static let sourceIdentifier = "hackingwithswift"

    private let urlSession: URLSession
    private let searchParser = HWSSearchResultParser()
    private let contentFetcher = HWSContentFetcher()
    private var cache: [String: DocumentContent] = [:]

    func search(query: String, maxResults: Int) async throws -> [SearchResult] {
        // 1. URL encode query
        // 2. Fetch search results page HTML
        // 3. Parse HTML to extract result cards
        // 4. Return SearchResult array
    }

    func fetch(_ result: SearchResult) async throws -> DocumentContent {
        // 1. Check cache
        // 2. Fetch page HTML
        // 3. Convert HTML to markdown
        // 4. Apply cleanup rules
        // 5. Return DocumentContent
    }
}
```

**Key decisions**:
- Use `actor` for thread-safe caching
- In-memory cache with URL as key
- Standard URLSession configuration

#### 2. HWSSearchResultParser

**Responsibility**: Parse HTML search results page to extract result metadata

```swift
struct HWSSearchResultParser {
    func parse(_ html: String) throws -> [HWSSearchResultItem] {
        // Parse HTML to extract:
        // - Title
        // - URL
        // - Summary/snippet
        // - Content type (article, tutorial, example-code, etc.)
        // - Breadcrumbs if available
    }
}

struct HWSSearchResultItem {
    let title: String
    let url: URL
    let summary: String?
    let contentType: String?
    let breadcrumbs: [String]
}
```

**Parsing strategy**:
- Use basic string operations and regex for initial implementation
- Look for common HTML patterns in search result cards
- Extract href attributes for URLs
- Extract text content for titles/summaries
- Identify content type from URL patterns (/articles/, /example-code/, /quick-start/, etc.)

**Example HTML structure to target** (hypothetical - needs verification):
```html
<div class="search-result">
    <h3><a href="/example-code/...">Title</a></h3>
    <p class="summary">Summary text...</p>
    <span class="category">Example Code</span>
</div>
```

#### 3. HWSContentFetcher

**Responsibility**: Fetch HTML pages and convert to markdown

```swift
struct HWSContentFetcher {
    private let cleaner = HWSMarkdownCleaner()

    func fetch(url: URL) async throws -> String {
        // 1. Fetch HTML from URL
        // 2. Convert HTML to markdown using basic conversion
        // 3. Apply cleanup rules via HWSMarkdownCleaner
        // 4. Return cleaned markdown
    }

    private func htmlToMarkdown(_ html: String) -> String {
        // Basic HTML to Markdown conversion:
        // - Extract <article> or <main> content area
        // - Convert <h1>-<h6> to # markdown
        // - Convert <p> to paragraphs
        // - Convert <code> and <pre> to backticks/code blocks
        // - Convert <a> to [text](url)
        // - Convert <ul>/<ol> to markdown lists
        // - Convert <strong>/<b> to **bold**
        // - Convert <em>/<i> to *italic*
        // - Strip <script>, <style>, <nav>, <header>, <footer>
    }
}
```

**HTML to Markdown strategy**:
- **Phase 1 (MVP)**: Basic regex-based conversion for common elements
- **Phase 2 (Optional)**: Consider SwiftSoup for more robust parsing if needed
- Focus on main content area (likely `<article>` or `<main>` tag)
- Preserve code blocks with language hints where available

#### 4. HWSMarkdownCleaner

**Responsibility**: Apply cleanup rules to remove HWS-specific boilerplate

```swift
struct HWSMarkdownCleaner {
    private let rules: [CleanupRule]

    init() {
        // Initialize all cleanup rules in priority order
        self.rules = [
            // Navigation/Footer rules (highest priority)
            .sectionBoundary(/*...*/),
            // Promotional content rules
            .exactMatch(/*...*/),
            // Regex pattern rules
            .regex(/*...*/),
            // Line pattern rules
            .linePattern(/*...*/),
            // Cleanup rules (lowest priority - run last)
            .regex(/*...*/)
        ]
    }

    func clean(_ markdown: String) -> String {
        var result = markdown
        for rule in rules {
            result = rule.apply(to: result)
        }
        return result
    }
}

enum CleanupRule {
    case sectionBoundary(startMarker: String, endMarker: String?, inclusive: Bool)
    case exactMatch(pattern: String, maxRemove: Int)
    case regex(pattern: String, options: NSRegularExpression.Options)
    case linePattern(pattern: String)

    func apply(to markdown: String) -> String {
        // Apply the specific rule type
    }
}
```

**Rule implementation approach**:

1. **section_boundary**: Remove content between start and end markers
   ```swift
   if let startRange = markdown.range(of: startMarker),
      let endRange = markdown.range(of: endMarker, range: startRange.upperBound..<markdown.endIndex) {
       // Remove from startRange to endRange (inclusive or exclusive)
   }
   ```

2. **exact_match**: Remove exact string matches
   ```swift
   markdown.replacingOccurrences(of: pattern, with: "", options: .literal, range: nil)
   // Repeat maxRemove times if > 0, or until no more matches if -1
   ```

3. **regex**: Remove regex matches
   ```swift
   let regex = try NSRegularExpression(pattern: pattern, options: options)
   return regex.stringByReplacingMatches(in: markdown, options: [], range: NSRange(markdown.startIndex..., in: markdown), withTemplate: "")
   ```

4. **line_pattern**: Remove lines matching pattern
   ```swift
   let lines = markdown.components(separatedBy: .newlines)
   let regex = try NSRegularExpression(pattern: pattern)
   let filtered = lines.filter { line in
       let range = NSRange(line.startIndex..., in: line)
       return regex.firstMatch(in: line, range: range) == nil
   }
   return filtered.joined(separator: "\n")
   ```

**Rule organization**:
- Group rules by category (navigation, promotional, UI, cleanup)
- Apply in order: structural rules first (section_boundary), then content rules, then cleanup rules last
- Consider rule dependencies (some cleanup rules should run after content removal)

### Implementation Phases

#### Phase 1: Foundation (MVP)

**Goal**: Basic search and content fetching working end-to-end

**Tasks**:
1. Create `HWSRetriever.swift` in `Models/` directory
2. Implement basic `search()` method with URL construction
3. Implement `HWSSearchResultParser` with regex-based HTML parsing
4. Test search with a few queries, validate result extraction

**Acceptance criteria**:
- Can search HWS and get back `[SearchResult]` with titles and URLs
- Results include basic metadata (title, URL, summary)
- No crashes on malformed HTML

**Estimated effort**: 2-3 hours

#### Phase 2: Content Fetching

**Goal**: Fetch and convert individual pages to markdown

**Tasks**:
1. Implement `HWSContentFetcher` with basic HTML-to-markdown conversion
2. Focus on converting: headings, paragraphs, code blocks, links, lists
3. Add basic content area extraction (find `<article>` or `<main>`)
4. Test with 3-5 different page types (article, tutorial, example-code)

**Acceptance criteria**:
- Can fetch a page and get markdown back
- Code blocks are preserved with language hints
- Headings, lists, and formatting are correct
- Main content is extracted (nav/footer excluded at HTML level)

**Estimated effort**: 3-4 hours

#### Phase 3: Core Cleanup Rules

**Goal**: Implement top 20 most critical cleanup rules

**Tasks**:
1. Create `HWSMarkdownCleaner.swift` in `Utils/` directory
2. Implement `CleanupRule` enum with all four types
3. Add top 20 rules from YAML config:
   - Navigation menu removal (section_boundary)
   - Footer removal (section_boundary × 3)
   - Login prompts (exact_match × 3)
   - Empty headers (regex × 2)
   - Back navigation links (regex)
   - Newsletter sections (regex)
   - About Me sections (regex)
   - Social sharing (section_boundary)
   - Rating widgets (regex)
   - Author bylines (regex)
   - Navigation tables (regex × 3)
   - Empty elements cleanup (regex × 2)
4. Test with diverse pages to verify cleanup

**Acceptance criteria**:
- Navigation and footer content removed
- Promotional sections removed
- Core content preserved and readable
- No over-aggressive removal of actual content

**Estimated effort**: 4-5 hours

#### Phase 4: Complete Cleanup Implementation

**Goal**: Implement all remaining cleanup rules

**Tasks**:
1. Add remaining ~60 cleanup rules from YAML
2. Group rules by category for maintainability
3. Add rule ordering/priority logic
4. Test with edge cases (interview questions, 100 Days content, forums, etc.)
5. Optimize performance if needed (rule caching, parallel processing)

**Acceptance criteria**:
- All 80+ rules implemented
- Pages from all content types clean correctly
- Performance is acceptable (<500ms for typical page)

**Estimated effort**: 3-4 hours

#### Phase 5: Integration & Polish

**Goal**: Integrate HWS retriever into the app and polish UX

**Tasks**:
1. Update `AppState` to include "hackingwithswift" source
2. Update `SidebarView` to show HWS toggle
3. Update `DetailView` icon logic for HWS branding
4. Update `AppState.performSearch()` to query HWS retriever when enabled
5. Add caching layer to HWSRetriever
6. Test search with HWS enabled alongside Apple Docs
7. Handle edge cases (no results, network errors, malformed HTML)

**Acceptance criteria**:
- HWS appears in sidebar and can be toggled
- Search results from HWS appear alongside Apple Docs results
- HWS content displays correctly in detail view
- Errors are handled gracefully
- Cache improves performance on repeated fetches

**Estimated effort**: 2-3 hours

#### Phase 6: Testing & Refinement

**Goal**: Comprehensive testing and bug fixes

**Tasks**:
1. Test with diverse queries: beginner topics, advanced topics, specific APIs
2. Test with different content types: articles, tutorials, example code, interview questions, Swift changes
3. Verify cleanup rules don't remove actual content
4. Test error handling: network failures, 404s, malformed HTML
5. Test performance with many results
6. Add unit tests for cleanup rules
7. Add integration tests for search and fetch

**Acceptance criteria**:
- All content types render correctly
- No false positives in cleanup (content removal)
- Handles errors gracefully
- Performance is acceptable
- Test coverage for critical paths

**Estimated effort**: 3-4 hours

### Technical Challenges & Solutions

#### Challenge 1: HTML Parsing Without External Dependencies

**Problem**: Foundation doesn't include a robust HTML parser. Options are:
- SwiftSoup (external dependency)
- XMLParser (not designed for HTML, fragile)
- Regex-based string parsing (limited but lightweight)

**Solution**: Start with regex-based parsing for MVP, defer decision on SwiftSoup
- **Phase 1-2**: Use regex for search result parsing and basic HTML-to-markdown
- **Phase 3+**: Evaluate if regex is sufficient or if SwiftSoup is needed
- If SwiftSoup is needed, add as SPM dependency

**Risk mitigation**: Design `HWSContentFetcher` to make HTML parsing swappable

#### Challenge 2: 80+ Cleanup Rules Complexity

**Problem**: Managing 80+ cleanup rules is complex and error-prone

**Solutions**:
1. **Rule ordering**: Apply rules in logical order (structural → content → cleanup)
2. **Rule grouping**: Organize rules by category with comments
3. **Incremental implementation**: Start with top 20, validate, then add rest
4. **Testing**: Create test markdown samples for each rule category
5. **Performance**: Profile rule application, optimize hot paths if needed

**Risk mitigation**: Build `CleanupRule` enum to be easily testable in isolation

#### Challenge 3: Content Type Diversity

**Problem**: HWS has many content types with different structures:
- Articles (blog posts)
- Tutorials (step-by-step guides)
- Example code (code snippets with explanations)
- Interview questions (Q&A format)
- Swift version changes (technical release notes)
- Forums (discussion threads)
- Course content (HWS+ premium)

**Solution**: Test with samples from each type, tune cleanup rules per type
- Use URL patterns to identify content type
- Apply type-specific cleanup rules if needed
- Document which types work best and which need refinement

**Risk mitigation**: Start with most common types (articles, tutorials, example code)

#### Challenge 4: Maintaining Rule Parity with site2chunks

**Problem**: The YAML config is maintained separately and may evolve

**Solution**:
- Document the source YAML config file in code comments
- Add versioning/timestamp to track which YAML version we're implementing
- Consider occasional sync checks against upstream config

**Risk mitigation**: Comprehensive testing will catch rule drift

### Testing Strategy

#### Unit Tests

1. **CleanupRule tests**: Test each rule type in isolation
   ```swift
   func testSectionBoundaryRemoval() {
       let rule = CleanupRule.sectionBoundary(
           startMarker: "## Start",
           endMarker: "## End",
           inclusive: true
       )
       let input = "Before\n## Start\nContent\n## End\nAfter"
       let output = rule.apply(to: input)
       XCTAssertEqual(output, "Before\nAfter")
   }
   ```

2. **HTML-to-markdown tests**: Verify conversion of common HTML elements
   ```swift
   func testCodeBlockConversion() {
       let html = "<pre><code class=\"swift\">let x = 5</code></pre>"
       let markdown = htmlToMarkdown(html)
       XCTAssertTrue(markdown.contains("```swift"))
       XCTAssertTrue(markdown.contains("let x = 5"))
   }
   ```

3. **Search result parsing tests**: Verify extraction from HTML
   ```swift
   func testSearchResultParsing() {
       let html = loadFixture("search-results.html")
       let results = try parser.parse(html)
       XCTAssertGreaterThan(results.count, 0)
       XCTAssertNotNil(results.first?.title)
   }
   ```

#### Integration Tests

1. **End-to-end search test**: Search → parse → verify results
2. **End-to-end fetch test**: Fetch page → convert → clean → verify markdown
3. **Cache test**: Fetch twice, verify second is from cache

#### Manual Testing

1. Test with curated list of ~20 diverse URLs from HWS
2. Verify each page renders correctly in DetailView
3. Compare rendered markdown to original webpage
4. Check that no actual content was removed by cleanup rules

### Performance Considerations

**Expected bottlenecks**:
1. Network requests (HTML fetching)
2. Regex operations in cleanup rules (80+ patterns)
3. HTML-to-markdown conversion

**Optimizations**:
1. **Caching**: In-memory cache for fetched content (already in actor design)
2. **Rule optimization**: Combine similar regex patterns where possible
3. **Early termination**: Stop processing if essential markers aren't found
4. **Lazy application**: Only apply rules relevant to detected content type
5. **Parallel processing**: Could run independent rules in parallel (measure first)

**Performance targets**:
- Search: < 2 seconds for typical query
- Fetch + convert + clean: < 1 second for typical page
- Cache hit: < 50ms

### File Structure

```
Swiftling/Swiftling/
├── Models/
│   ├── KnowledgeRetriever.swift (existing)
│   ├── AppleDocsRetriever.swift (existing)
│   ├── HWSRetriever.swift (new)
│   ├── HWSSearchResultParser.swift (new)
│   └── HWSContentFetcher.swift (new)
├── Utils/
│   ├── MarkdownUtilities.swift (existing)
│   ├── JSONDecodingUtilities.swift (existing)
│   └── HWSMarkdownCleaner.swift (new)
├── Views/
│   └── (existing views, no changes needed)
└── Tests/ (create if doesn't exist)
    ├── HWSRetrieverTests.swift
    ├── HWSCleanupRuleTests.swift
    └── fixtures/
        ├── search-results.html
        ├── article-sample.html
        ├── tutorial-sample.html
        └── example-code-sample.html
```

### Risks & Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| HTML structure changes on HWS | High | Medium | Test with diverse pages; design for resilience; version detection |
| Cleanup rules too aggressive | High | Medium | Comprehensive testing; whitelist critical patterns |
| Performance issues with 80+ rules | Medium | Low | Profile early; optimize hot paths; consider rule caching |
| External dependency needed (SwiftSoup) | Low | Medium | Design for swappable parsing; evaluate in Phase 2 |
| Content type not supported | Medium | Medium | Document supported types; graceful degradation |

### Success Criteria

**Must have** (MVP):
- ✅ Search HWS and get relevant results
- ✅ Fetch and display article/tutorial content
- ✅ Core cleanup rules implemented (nav, footer, promotional)
- ✅ Markdown rendering works in DetailView
- ✅ No crashes or major bugs

**Should have**:
- ✅ All 80+ cleanup rules implemented
- ✅ Support for all major content types
- ✅ Caching for performance
- ✅ Error handling and graceful degradation
- ✅ Unit tests for critical paths

**Nice to have**:
- 🔲 Breadcrumb extraction from pages
- 🔲 Content type detection from page structure
- 🔲 Relevance scoring for search results
- 🔲 Preview/summary generation
- 🔲 SwiftSoup integration for robust parsing

### Next Steps

1. **Review this plan** with stakeholders
2. **Create feature branch**: `feature/hws-retriever`
3. **Start Phase 1**: Implement basic search and result parsing
4. **Iterate through phases** with testing at each stage
5. **Merge to main** after Phase 6 completion

### Estimated Total Effort

- Phase 1: 2-3 hours
- Phase 2: 3-4 hours
- Phase 3: 4-5 hours
- Phase 4: 3-4 hours
- Phase 5: 2-3 hours
- Phase 6: 3-4 hours

**Total: 17-23 hours** (2-3 days of focused work)

### Open Questions

1. Should we use SwiftSoup for HTML parsing or stick with regex?
2. How should we handle HWS+ premium content (requires login)?
3. Should we extract and display code playground files?
4. How do we handle forum content vs. article content differently?
5. Should we pre-fetch related content for better UX?

These questions can be answered during implementation based on what we discover.
