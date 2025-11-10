//
//  AppState.swift
//  Swiftling
//
//  Created by Claude Code on 09.11.25.
//

import Foundation
import SwiftUI

// MARK: - App State

/// Centralized state management for the Swiftling app
/// Uses @Observable (iOS 17+) for automatic change tracking
@Observable
class AppState {
    // MARK: - Search State

    /// Set of enabled knowledge sources (e.g., "apple-docs", "hackingwithswift")
    var enabledSources: Set<String> = ["apple-docs", "hackingwithswift"]

    /// Current search query string
    var currentQuery: String = ""

    /// Array of search results from enabled sources
    var searchResults: [SearchResult] = []

    /// Currently selected result for detail view
    var selectedResult: SearchResult?

    /// Whether a search is currently in progress
    var isSearching: Bool = false

    /// Error from the last search operation, if any
    var searchError: Error?

    /// Map of source identifier to error (for partial failures)
    var sourceErrors: [String: Error] = [:]

    // MARK: - Reranking State

    /// Current state of the rerank button
    var rerankButtonState: RerankButtonState = .ready

    /// Whether reranking is in progress
    var isReranking: Bool = false

    /// Error from the last rerank operation, if any
    var rerankError: Error?

    /// The reranker instance
    private let reranker = Reranker()

    // MARK: - Initialization

    init() {}

    // MARK: - Search Operations

    /// Perform a search across all enabled knowledge sources
    /// - Parameter query: The search query string
    func performSearch(query: String) async {
        guard !query.isEmpty else { return }

        // Update state
        self.currentQuery = query
        self.isSearching = true
        self.searchError = nil
        self.sourceErrors = [:]
        self.searchResults = []
        self.selectedResult = nil

        // Reset rerank state for new search
        self.rerankButtonState = .ready
        self.rerankError = nil

        var allResults: [SearchResult] = []
        var hasAnyResults = false

        // Search each enabled source independently (don't fail if one fails)
        if enabledSources.contains("apple-docs") {
            do {
                let retriever = AppleDocsRetriever()
                let results = try await retriever.search(query: query, maxResults: 10)
                allResults.append(contentsOf: results)
                hasAnyResults = true
            } catch {
                // Store error for this source but continue
                sourceErrors["apple-docs"] = error
                print("Apple Docs search failed: \(error.localizedDescription)")
            }
        }

        if enabledSources.contains("hackingwithswift") {
            do {
                let retriever = HWSKnowledgeRetriever()
                let results = try await retriever.search(query: query, maxResults: 10)
                allResults.append(contentsOf: results)
                hasAnyResults = true
            } catch {
                // Store error for this source but continue
                sourceErrors["hackingwithswift"] = error
                print("HackingWithSwift search failed: \(error.localizedDescription)")
            }
        }

        // TODO: Add GitHub retriever when implemented

        // Update results
        self.searchResults = allResults
        self.isSearching = false

        // If all sources failed, set a general error
        if !hasAnyResults && !sourceErrors.isEmpty {
            self.searchError = SearchError.allSourcesFailed(sourceErrors: sourceErrors)
        }

        // Auto-select first result if available
        if let first = allResults.first {
            self.selectedResult = first
        }
    }

    /// Clear all search state
    func clearSearch() {
        currentQuery = ""
        searchResults = []
        selectedResult = nil
        searchError = nil
        isSearching = false
        rerankButtonState = .ready
        rerankError = nil
    }

    // MARK: - Reranking Operations

    /// Rerank the current search results using AI
    func performRerank() async {
        guard !searchResults.isEmpty else { return }
        guard !isReranking else { return } // Prevent multiple simultaneous reranks

        // Update state
        isReranking = true
        rerankButtonState = .reranking
        rerankError = nil

        do {
            // Set original positions before reranking
            let resultsWithPositions = searchResults.enumerated().map { index, result in
                var updated = result
                updated.originalPosition = index
                return updated
            }

            // Perform reranking
            let reranked = try await reranker.rerank(
                results: resultsWithPositions,
                query: currentQuery
            )

            // Update results
            searchResults = reranked

            // Update button state
            rerankButtonState = .completed
            isReranking = false

        } catch {
            rerankError = error
            rerankButtonState = .ready
            isReranking = false
        }
    }

    /// Reset reranking state (allows re-ranking)
    func resetRerank() {
        rerankButtonState = .ready
        rerankError = nil
    }
}

// MARK: - Supporting Types

/// State of the rerank button
enum RerankButtonState {
    /// Ready to rerank - button is enabled
    case ready

    /// Currently reranking - button is disabled with spinner
    case reranking

    /// Reranking completed - button is disabled with checkmark
    case completed
}

/// Errors specific to search operations
enum SearchError: Error, LocalizedError {
    /// All enabled sources failed to return results
    case allSourcesFailed(sourceErrors: [String: Error])

    var errorDescription: String? {
        switch self {
        case .allSourcesFailed(let sourceErrors):
            let failedSources = sourceErrors.keys.joined(separator: ", ")
            return "All sources failed: \(failedSources)"
        }
    }
}
