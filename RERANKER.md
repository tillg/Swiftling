# RERANKER

The reranker should

* Be triggered by the user, i.e. a button
* Is only clickable when there is a search result
* Reranking means:
  * All the results, together with the question are sent to the LLM
  * We ask the LLM to put them in an order from best to worst
* Reranking should be shown in a visual appealing and understanding way - how?

## Questions & Answers

### What is a good reranker-prompt?

A good reranker prompt should be:
1. **Clear and structured** - Use numbered list format for easy parsing
2. **Minimal context** - Only include essential metadata (title, description, type, breadcrumbs)
3. **Explicit instructions** - Ask for a specific output format (JSON array of IDs)

**Recommended prompt structure:**

```
You are a search result ranker for Swift and iOS development questions.

User's question: "{query}"

Search results to rank:
1. [ID: result-1] Title: "{title}" | Type: {type} | Description: "{description}"
2. [ID: result-2] Title: "{title}" | Type: {type} | Description: "{description}"
...

Task: Rank these results from MOST to LEAST relevant to answer the user's question.
Consider:
- Direct relevance to the question
- Depth of information (articles > brief references)
- Authority of source (official docs > tutorials)
- Recency (if question implies version-specific info)

Output ONLY a JSON array of IDs in ranked order: ["result-X", "result-Y", ...]
```

### How big can a prompt be for our LLM? Isn't all this content too much?

**Apple Foundation Models context limits:**
- The 3B on-device model has a **limited context window** (typically ~4K-8K tokens)
- Each search result's metadata (title + description + breadcrumbs) ≈ 100-200 tokens
- With 10 results: ~1,000-2,000 tokens for results + prompt overhead

**Token budget strategy:**
```
Prompt overhead:        ~200 tokens
User query:            ~50 tokens
Per-result metadata:   ~150 tokens
10 results:            ~1,500 tokens
-----------------------------------
Total:                 ~1,750 tokens (well within limits)
```

**Safe approach:** Limit reranking to **first 10-15 results** to stay comfortably under context limits.

### How do we deal if it's too much?

**Three-tier strategy:**

1. **Truncation strategy (Recommended)**
   - Only send top 10-15 results to reranker
   - Show reranked results first, followed by remaining unranked results
   - Add visual separator: "--- Reranked Results Above ---"

2. **Summarization strategy (If needed)**
   - Truncate descriptions to first 50 words
   - Remove breadcrumbs (use only title + type + shortened description)
   - Reduces per-result tokens from ~150 to ~50

3. **Batch reranking (Advanced)**
   - If >15 results, rank in batches of 10
   - Merge results using a tournament-style approach
   - More complex, probably overkill for v1

**Recommended implementation:**
```swift
func rerank(results: [SearchResult], query: String) async -> [SearchResult] {
    // Take top 15 results only
    let resultsToRank = Array(results.prefix(15))

    // Check token count
    let estimatedTokens = estimateTokenCount(query: query, results: resultsToRank)

    if estimatedTokens > 6000 {
        // Fallback: truncate descriptions
        let truncated = resultsToRank.map { truncateDescription($0, maxWords: 50) }
        return await performReranking(truncated, query: query)
    }

    return await performReranking(resultsToRank, query: query)
}
```

### Maybe we need a summary generation process for the searchResults?

**Not recommended for reranking.** Here's why:

**Pros:**
- Reduces token count
- Could theoretically rank more results

**Cons:**
- **Adds latency** - Requires two LLM calls (summarize → rank)
- **Loses information** - Summaries might miss key relevance signals
- **Complexity** - More failure points, harder to debug
- **Diminishing returns** - Top 10-15 results are usually sufficient

**Better alternative:** Use metadata more efficiently
- Title + Type + First sentence of description = usually enough
- Breadcrumbs provide category context with minimal tokens
- Result type (article vs. API reference) is a strong signal

---

## Visual Design for Reranking

### UX Flow

1. **Before reranking:**
   ```
   [Rerank with AI] button (enabled when results exist)
   ↓
   Search Results (1-N)
   - Result 1
   - Result 2
   - Result 3
   ```

2. **During reranking:**
   ```
   [⟳ Reranking...] button (disabled, animated)
   ↓
   Search Results (slightly dimmed)
   ```

3. **After reranking:**
   ```
   [✓ Reranked] button (disabled, shows success)
   ↓
   🎯 AI-Reranked Results
   - Result 3 ↑↑  (with animation)
   - Result 1 ↓
   - Result 2 ↓

   --- Other Results ---
   - Result 4
   - Result 5
   ```

### Visual Indicators

**Reranked results badge:**
```swift
HStack {
    Image(systemName: "sparkles")
    Text("AI Reranked")
}
.font(.caption)
.foregroundStyle(.purple)
.padding(.horizontal, 8)
.padding(.vertical, 4)
.background(Color.purple.opacity(0.1))
.cornerRadius(4)
```

**Movement indicators:**
- Show subtle arrow icons: `↑↑` (moved up significantly), `↑` (moved up), `↓` (moved down)
- Animate position changes with smooth transitions
- Highlight top result with gold/purple border

**Button states:**
```swift
enum RerankButtonState {
    case ready      // "Rerank with AI" - tappable
    case reranking  // "Reranking..." - disabled, animated spinner
    case completed  // "Reranked" - disabled, checkmark icon
}
```

### Error Handling

**If reranking fails:**
1. Show toast: "Reranking failed. Showing original order."
2. Keep original result order
3. Button returns to "ready" state
4. Log error for debugging

**If LLM returns incomplete ranking:**
1. Use partial results where possible
2. Append unranked results at end
3. Show warning badge: "Partial reranking"

---

## Implementation Considerations

### Data Model

```swift
struct SearchResult {
    let id: String
    let title: String
    let description: String
    let url: URL
    let breadcrumbs: [String]
    let tags: [String]
    let type: ResultType

    // Reranking metadata
    var rankPosition: Int?           // Original position
    var rerankedPosition: Int?       // New position after reranking
    var rerankScore: Double?         // Confidence score from LLM (optional)
}

enum ResultType: String {
    case documentation = "Documentation"
    case article = "Article"
    case tutorial = "Tutorial"
    case video = "Video"
    case reference = "API Reference"
}
```

### Foundation Models Integration

```swift
import FoundationModels

actor Reranker {
    private let session: LanguageModelSession

    func rerank(results: [SearchResult], query: String) async throws -> [SearchResult] {
        let prompt = buildRerankPrompt(query: query, results: results)

        let response = try await session.generate(
            prompt: prompt,
            maxTokens: 100  // Just need JSON array of IDs
        )

        let rankedIDs = try parseRankedIDs(from: response)
        return reorderResults(results, by: rankedIDs)
    }

    private func buildRerankPrompt(query: String, results: [SearchResult]) -> String {
        // Implementation following recommended prompt structure above
    }
}
```

### Performance Optimization

1. **Cache rerank results** - Don't re-rank same query twice in a session
2. **Debounce button** - Prevent multiple simultaneous rerank requests
3. **Background processing** - Don't block UI during LLM call
4. **Timeout handling** - Set 10-second timeout for LLM response

### Testing Strategy

1. **Unit tests:**
   - Token counting accuracy
   - Prompt generation with various result counts
   - JSON parsing of LLM responses

2. **Integration tests:**
   - End-to-end reranking flow
   - Fallback behavior when token limit exceeded
   - Error handling (network, LLM failure, invalid response)

3. **Manual testing scenarios:**
   - "How to use async/await" → Rank tutorials above API docs
   - "URLSession documentation" → Rank API docs above tutorials
   - "SwiftUI animation examples" → Rank articles with code above brief references

---

## Alternative: Semantic Similarity Reranking

**If Foundation Models reranking proves too slow/unreliable:**

Use **on-device embeddings** (NaturalLanguage framework):
1. Generate embeddings for query
2. Generate embeddings for each result (title + description)
3. Calculate cosine similarity
4. Rerank by similarity score

**Pros:**
- Much faster (~100ms vs ~2-5s for LLM)
- No token limits
- Fully deterministic
- No internet required

**Cons:**
- Less "intelligent" - can't reason about relevance
- No understanding of result type importance
- Might not capture semantic nuances

**Hybrid approach:**
- Use embeddings for initial fast rerank
- Offer optional "AI Rerank" button for LLM-powered refinement

---

## Recommendation

**Phase 1 (MVP):**
1. Implement basic LLM reranker with top 10 results
2. Simple visual indicators (badge + subtle animations)
3. Error handling with fallback to original order

**Phase 2 (Enhancement):**
1. Add token counting and smart truncation
2. Implement caching for repeated queries
3. Add movement indicators and better animations

**Phase 3 (Advanced):**
1. Experiment with hybrid embedding + LLM approach
2. Add confidence scores and "explain ranking" feature
3. Learn from user interactions (click-through rate by position)