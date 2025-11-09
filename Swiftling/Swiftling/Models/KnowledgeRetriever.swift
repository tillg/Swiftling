//
//  KnowledgeRetriever.swift
//  Swiftling
//
//  Created by Claude Code on 09.11.25.
//

import Foundation

// MARK: - Core Protocol

/// Core protocol for retrieving knowledge from documentation sources
protocol KnowledgeRetriever: Sendable {
    /// Unique identifier for this retriever (e.g., "apple-docs", "github")
    var sourceIdentifier: String { get }

    /// Human-readable name for this source
    var sourceName: String { get }

    /// Search for documentation matching the query
    /// - Parameters:
    ///   - query: The search query string
    ///   - maxResults: Maximum number of results to return (0 = unrestricted, default: 0)
    /// - Returns: Array of search results, ordered by relevance
    /// - Throws: `KnowledgeRetrieverError` on failure
    func search(query: String, maxResults: Int) async throws -> [SearchResult]

    /// Fetch and convert a specific document to Markdown
    /// - Parameter result: The search result to fetch
    /// - Returns: Document content in Markdown format
    /// - Throws: `KnowledgeRetrieverError` on failure
    func fetch(_ result: SearchResult) async throws -> DocumentContent

    /// Convenience method: search and fetch the top result
    /// - Parameter query: The search query string
    /// - Returns: Document content in Markdown format, or nil if no results
    /// - Throws: `KnowledgeRetrieverError` on failure
    func searchAndFetch(query: String) async throws -> DocumentContent?
}

/// Default implementations
extension KnowledgeRetriever {
    /// Search with default maxResults = 0 (unrestricted)
    func search(query: String) async throws -> [SearchResult] {
        try await search(query: query, maxResults: 0)
    }

    func searchAndFetch(query: String) async throws -> DocumentContent? {
        let results = try await search(query: query, maxResults: 0)
        guard let topResult = results.first else {
            return nil
        }
        return try await fetch(topResult)
    }
}

// MARK: - Data Models

/// Represents a single search result from a documentation source
struct SearchResult: Sendable, Identifiable, Hashable {
    /// Unique identifier for this result
    let id: UUID

    /// The title of the documentation page
    let title: String

    /// Brief description or summary
    let summary: String?

    /// URL to the documentation page
    let url: URL

    /// Source identifier (matches KnowledgeRetriever.sourceIdentifier)
    let sourceIdentifier: String

    /// Breadcrumb path to this documentation (e.g., ["Swift", "Array", "Element"])
    let breadcrumbs: [String]

    /// Tags or categories for this result
    let tags: [String]

    /// Type of result (e.g., "documentation", "general", "sample-code")
    let resultType: String?

    /// Relevance score (0.0 to 1.0), if available
    let relevanceScore: Double?

    /// Additional metadata (e.g., API type, language, version)
    let metadata: [String: String]

    init(
        id: UUID = UUID(),
        title: String,
        summary: String? = nil,
        url: URL,
        sourceIdentifier: String,
        breadcrumbs: [String] = [],
        tags: [String] = [],
        resultType: String? = nil,
        relevanceScore: Double? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.url = url
        self.sourceIdentifier = sourceIdentifier
        self.breadcrumbs = breadcrumbs
        self.tags = tags
        self.resultType = resultType
        self.relevanceScore = relevanceScore
        self.metadata = metadata
    }
}

/// Represents fetched and processed documentation content
struct DocumentContent: Sendable {
    /// The search result this content corresponds to
    let searchResult: SearchResult

    /// The document content in Markdown format
    let markdown: String

    /// Original fetch timestamp
    let fetchedAt: Date

    /// Optional raw data (for caching/debugging)
    let rawData: Data?

    init(
        searchResult: SearchResult,
        markdown: String,
        fetchedAt: Date = Date(),
        rawData: Data? = nil
    ) {
        self.searchResult = searchResult
        self.markdown = markdown
        self.fetchedAt = fetchedAt
        self.rawData = rawData
    }
}

// MARK: - Error Handling

/// Errors that can occur during knowledge retrieval
enum KnowledgeRetrieverError: Error, LocalizedError {
    /// Network request failed
    case networkError(underlying: Error)

    /// The search returned no results
    case noResults

    /// Failed to parse the response
    case parsingError(description: String)

    /// The requested resource was not found (404)
    case notFound(url: URL)

    /// Rate limit exceeded
    case rateLimitExceeded(retryAfter: TimeInterval?)

    /// Authentication or authorization failed
    case authenticationFailed

    /// Invalid query or parameters
    case invalidRequest(description: String)

    /// Generic error with description
    case unknownError(description: String)

    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .noResults:
            return "No results found for the query"
        case .parsingError(let description):
            return "Failed to parse response: \(description)"
        case .notFound(let url):
            return "Resource not found: \(url.absoluteString)"
        case .rateLimitExceeded(let retryAfter):
            if let retryAfter = retryAfter {
                return "Rate limit exceeded. Retry after \(retryAfter) seconds"
            }
            return "Rate limit exceeded"
        case .authenticationFailed:
            return "Authentication failed"
        case .invalidRequest(let description):
            return "Invalid request: \(description)"
        case .unknownError(let description):
            return "Unknown error: \(description)"
        }
    }
}

// MARK: - Caching Support

/// Protocol for caching retrieved documentation
protocol KnowledgeCache: Sendable {
    /// Retrieve cached content for a URL
    func get(url: URL) async -> DocumentContent?

    /// Store content in cache
    func set(_ content: DocumentContent, for url: URL) async

    /// Clear the entire cache
    func clear() async

    /// Remove expired entries
    func removeExpired() async
}

/// Simple in-memory cache implementation
actor InMemoryKnowledgeCache: KnowledgeCache {
    private var storage: [URL: CachedEntry] = [:]
    private let maxAge: TimeInterval

    struct CachedEntry {
        let content: DocumentContent
        let cachedAt: Date
    }

    init(maxAge: TimeInterval = 3600) { // 1 hour default
        self.maxAge = maxAge
    }

    func get(url: URL) async -> DocumentContent? {
        guard let entry = storage[url] else { return nil }

        // Check if expired
        if Date().timeIntervalSince(entry.cachedAt) > maxAge {
            storage.removeValue(forKey: url)
            return nil
        }

        return entry.content
    }

    func set(_ content: DocumentContent, for url: URL) async {
        storage[url] = CachedEntry(content: content, cachedAt: Date())
    }

    func clear() async {
        storage.removeAll()
    }

    func removeExpired() async {
        let now = Date()
        storage = storage.filter { _, entry in
            now.timeIntervalSince(entry.cachedAt) <= maxAge
        }
    }
}
