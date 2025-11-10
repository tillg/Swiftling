//
//  HWSRetriever.swift
//  Swiftling
//
//  Created by Claude Code on 09.11.25.
//

import Foundation

/// Knowledge retriever for HackingWithSwift.com
actor HWSKnowledgeRetriever: KnowledgeRetriever {

    // MARK: - KnowledgeRetriever Protocol

    nonisolated let sourceIdentifier = "hackingwithswift"
    nonisolated let sourceName = "Hacking with Swift"

    // MARK: - Properties

    private let urlSession: URLSession
    private let searchParser = HWSSearchResultParser()
    private let contentFetcher: HWSContentFetcher
    private var cache: [URL: DocumentContent] = [:]

    // MARK: - Initialization

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        self.contentFetcher = HWSContentFetcher(urlSession: urlSession)
    }

    // MARK: - Search

    func search(query: String, maxResults: Int = 0) async throws -> [SearchResult] {
        // URL encode the query
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw KnowledgeRetrieverError.invalidRequest(description: "Could not encode query")
        }

        // Construct search URL
        let searchURL = URL(string: "https://www.hackingwithswift.com/search/\(encodedQuery)")!

        // Fetch search results HTML
        let (data, response) = try await urlSession.data(from: searchURL)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw KnowledgeRetrieverError.networkError(
                underlying: URLError(.badServerResponse)
            )
        }

        // Handle HTTP errors
        switch httpResponse.statusCode {
        case 200:
            break // Success

        case 404:
            throw KnowledgeRetrieverError.notFound(url: searchURL)

        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { TimeInterval($0) }
            throw KnowledgeRetrieverError.rateLimitExceeded(retryAfter: retryAfter)

        case 401, 403:
            throw KnowledgeRetrieverError.authenticationFailed

        default:
            throw KnowledgeRetrieverError.networkError(
                underlying: URLError(.badServerResponse)
            )
        }

        // Parse HTML to extract search results
        guard let html = String(data: data, encoding: .utf8) else {
            throw KnowledgeRetrieverError.parsingError(
                description: "Could not decode search results as UTF-8"
            )
        }

        let items = try searchParser.parse(html)

        if items.isEmpty {
            throw KnowledgeRetrieverError.noResults
        }

        // Convert to SearchResult array
        var results = items.map { $0.toSearchResult() }

        // Apply maxResults limit if specified
        if maxResults > 0 && results.count > maxResults {
            results = Array(results.prefix(maxResults))
        }

        return results
    }

    // MARK: - Fetch

    func fetch(_ result: SearchResult) async throws -> DocumentContent {
        // Check cache first
        if let cached = cache[result.url] {
            return cached
        }

        // Fetch and convert to markdown
        let markdown = try await contentFetcher.fetch(url: result.url)

        // Create DocumentContent
        let content = DocumentContent(
            searchResult: result,
            markdown: markdown,
            fetchedAt: Date(),
            rawData: nil
        )

        // Store in cache
        cache[result.url] = content

        return content
    }

    // MARK: - Cache Management

    /// Clear the cache
    func clearCache() {
        cache.removeAll()
    }

    /// Get current cache size
    func cacheSize() -> Int {
        cache.count
    }
}
