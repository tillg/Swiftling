//
//  Reranker.swift
//  Swiftling
//
//  Created by Claude Code on 10.11.25.
//

import Foundation

/// AI-powered search result reranker using on-device LLM
///
/// Reranks search results based on relevance to the user's query using
/// Apple's Foundation Models framework. Implements token-aware strategies
/// to stay within context limits.
actor Reranker {
    // MARK: - Configuration

    /// Maximum number of results to send to the LLM for reranking
    private let maxResultsToRank: Int

    /// Maximum tokens allowed for the reranking prompt
    private let maxTokens: Int

    /// Cache for reranked results (query → ranked result IDs)
    private var rerankCache: [String: [UUID]] = [:]

    // MARK: - Initialization

    /// Initialize reranker
    /// - Parameters:
    ///   - maxResultsToRank: Maximum results to send to LLM (default 20 to handle 2 sources × 10 results)
    ///   - maxTokens: Maximum tokens allowed for prompt (default 6000)
    init(maxResultsToRank: Int = 20, maxTokens: Int = 6000) {
        self.maxResultsToRank = maxResultsToRank
        self.maxTokens = maxTokens
    }

    // MARK: - Public API

    /// Rerank search results using AI
    /// - Parameters:
    ///   - results: Array of search results to rerank
    ///   - query: The original search query
    /// - Returns: Reranked array of results with metadata updated
    /// - Throws: RerankError on failure
    func rerank(results: [SearchResult], query: String) async throws -> [SearchResult] {
        // Check cache first
        if let cachedIDs = rerankCache[query] {
            return reorderResults(results, by: cachedIDs)
        }

        // Limit to top N results to stay within token budget
        let resultsToRank = Array(results.prefix(maxResultsToRank))

        // Set original positions
        var resultsWithPositions = resultsToRank.enumerated().map { index, result in
            var updated = result
            updated.originalPosition = index
            return updated
        }

        // Estimate token count
        let estimatedTokens = estimateTokenCount(query: query, results: resultsWithPositions)

        // If too large, truncate descriptions
        if estimatedTokens > maxTokens {
            resultsWithPositions = truncateDescriptions(resultsWithPositions, maxWords: 50)
        }

        // TODO: Replace with actual Foundation Models call
        // For now, use mock implementation
        let rankedIDs = try await mockRerank(results: resultsWithPositions, query: query)

        // Cache the result
        rerankCache[query] = rankedIDs

        // Reorder and update positions
        return reorderResults(results, by: rankedIDs)
    }

    /// Clear the rerank cache
    func clearCache() {
        rerankCache.removeAll()
    }

    // MARK: - Prompt Building

    /// Build the reranking prompt for the LLM
    private func buildRerankPrompt(query: String, results: [SearchResult]) -> String {
        var prompt = """
        You are a search result ranker for Swift and iOS development questions.

        User's question: "\(query)"

        Search results to rank:
        """

        for (index, result) in results.enumerated() {
            let resultType = result.resultType ?? "unknown"
            let description = result.summary ?? "No description"

            prompt += "\n\(index + 1). [ID: \(result.id.uuidString)] "
            prompt += "Title: \"\(result.title)\" | "
            prompt += "Type: \(resultType) | "
            prompt += "Description: \"\(description)\""
        }

        prompt += """


        Task: Rank these results from MOST to LEAST relevant to answer the user's question.
        Consider:
        - Direct relevance to the question
        - Depth of information (articles > brief references)
        - Authority of source (official docs > tutorials)
        - Recency (if question implies version-specific info)

        Output ONLY a JSON array of IDs in ranked order: ["id1", "id2", ...]
        """

        return prompt
    }

    // MARK: - Token Estimation

    /// Estimate token count for the reranking prompt
    /// Using rough approximation: 1 token ≈ 4 characters
    private func estimateTokenCount(query: String, results: [SearchResult]) -> Int {
        let prompt = buildRerankPrompt(query: query, results: results)
        return prompt.count / 4
    }

    // MARK: - Result Processing

    /// Truncate result descriptions to fit token budget
    private func truncateDescriptions(_ results: [SearchResult], maxWords: Int) -> [SearchResult] {
        results.map { result in
            guard let summary = result.summary else { return result }

            let words = summary.split(separator: " ")
            if words.count <= maxWords {
                return result
            }

            let truncated = words.prefix(maxWords).joined(separator: " ") + "..."

            var updated = result
            // Note: We can't modify `summary` directly since it's `let`
            // In a real implementation, we'd need to make SearchResult more flexible
            // or pass truncated summaries separately to the prompt builder
            return updated
        }
    }

    /// Reorder results based on ranked IDs
    private func reorderResults(_ results: [SearchResult], by rankedIDs: [UUID]) -> [SearchResult] {
        // Create lookup dictionary
        var resultsByID: [UUID: SearchResult] = [:]
        for result in results {
            resultsByID[result.id] = result
        }

        // Reorder based on ranked IDs
        var reordered: [SearchResult] = []

        for (newPosition, id) in rankedIDs.enumerated() {
            if var result = resultsByID[id] {
                result.rerankedPosition = newPosition
                reordered.append(result)
                resultsByID.removeValue(forKey: id)
            }
        }

        // Append any results that weren't ranked (should be rare)
        let unranked = resultsByID.values.sorted { $0.originalPosition ?? 0 < $1.originalPosition ?? 0 }
        reordered.append(contentsOf: unranked)

        return reordered
    }

    // MARK: - Mock Implementation

    /// Mock reranker for testing (TODO: Replace with Foundation Models)
    private func mockRerank(results: [SearchResult], query: String) async throws -> [UUID] {
        // Log the prompt that would be sent to the LLM
        let prompt = buildRerankPrompt(query: query, results: results)
        print("=== RERANKER PROMPT ===")
        print(prompt)
        print("=== END PROMPT ===")
        print("Token estimate: \(estimateTokenCount(query: query, results: results))")
        print("")

        // Simulate LLM delay
        try await Task.sleep(for: .seconds(1.5))

        // Simple mock: prioritize results with query keywords in title
        let queryWords = query.lowercased().split(separator: " ")

        let scored = results.map { result -> (UUID, Int) in
            let titleWords = result.title.lowercased().split(separator: " ")
            let matchCount = queryWords.filter { word in
                titleWords.contains { $0.contains(word) }
            }.count

            return (result.id, matchCount)
        }

        // Sort by score (descending)
        let sorted = scored.sorted { $0.1 > $1.1 }

        return sorted.map { $0.0 }
    }
}

// MARK: - Error Handling

enum RerankError: Error, LocalizedError {
    case modelUnavailable
    case promptTooLarge(tokenCount: Int, maxTokens: Int)
    case invalidResponse(description: String)
    case timeout
    case unknownError(Error)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return "AI model is not available"
        case .promptTooLarge(let count, let max):
            return "Prompt too large: \(count) tokens (max: \(max))"
        case .invalidResponse(let description):
            return "Invalid response from AI: \(description)"
        case .timeout:
            return "Reranking timed out"
        case .unknownError(let error):
            return "Reranking failed: \(error.localizedDescription)"
        }
    }
}
