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

    /// Set of enabled knowledge sources (e.g., "apple-docs")
    var enabledSources: Set<String> = ["apple-docs"]

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
        self.searchResults = []
        self.selectedResult = nil

        do {
            var allResults: [SearchResult] = []

            // Search each enabled source
            if enabledSources.contains("apple-docs") {
                let retriever = AppleDocsRetriever()
                let results = try await retriever.search(query: query, maxResults: 10)
                allResults.append(contentsOf: results)
            }

            // TODO: Add other retrievers (HackingWithSwift, GitHub) when implemented

            // Update results
            self.searchResults = allResults
            self.isSearching = false

            // Auto-select first result if available
            if let first = allResults.first {
                self.selectedResult = first
            }

        } catch {
            self.searchError = error
            self.isSearching = false
        }
    }

    /// Clear all search state
    func clearSearch() {
        currentQuery = ""
        searchResults = []
        selectedResult = nil
        searchError = nil
        isSearching = false
    }
}
