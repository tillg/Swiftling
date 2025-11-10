//
//  AppleKnowledgeRetriever.swift
//  Swiftling
//
//  Created by Till Gartner on 09.11.25.
//

import Foundation
import Playgrounds

// Helper to repeat strings
private func * (string: String, count: Int) -> String {
    String(repeating: string, count: count)
}

#Playground("Direct Fetch Test")
{
    // Bypass search and directly test fetch with a known URL
    let retriever = AppleDocsRetriever()

    // Create a search result with a known Apple Docs URL
    let knownURL = URL(string: "https://developer.apple.com/documentation/foundation/urlsession")!
    let searchResult = SearchResult(
        title: "URLSession",
        summary: "An object that coordinates a group of related network data transfer tasks.",
        url: knownURL,
        sourceIdentifier: "apple-docs"
    )

    do {
        print("Fetching from: \(knownURL.absoluteString)")
        let content = try await retriever.fetch(searchResult)
        print("✅ Success!")
        print("📏 Markdown length: \(content.markdown.count) characters")
        print("\n📖 First 800 characters of Markdown:")
        print("-" * 60)
        print(String(content.markdown.prefix(800)))
        print("...")
    } catch {
        print("❌ Fetch failed: \(error)")
        if let retrievalError = error as? KnowledgeRetrieverError {
            print("   Details: \(retrievalError.errorDescription ?? "")")
        }
    }
}

#Playground("Apple Docs Retriever for 'URLSession'")
{
    let retriever = AppleDocsRetriever()
    
    // Test 1: Limited results (10)
    print("📍 Searching for 'URLSession' (limit: 10) ...")
    do {
        let results = try await retriever.search(query: "URLSession", maxResults: 10)
        print("✅ Found \(results.count) results\n")
        
        // Display the first 3 results
        for (index, result) in results.prefix(3).enumerated() {
            print("[\(index + 1)] \(result.title)")
            print("    URL: \(result.url.absoluteString)")
            if let summary = result.summary {
                print("    📝 \(summary)")
            }
            if let type = result.resultType {
                print("    🏷️  Type: \(type)")
            }
            if !result.breadcrumbs.isEmpty {
                print("    🗂️  \(result.breadcrumbs.joined(separator: " > "))")
            }
            if !result.tags.isEmpty {
                print("    🏷️  Tags: \(result.tags.joined(separator: ", "))")
            }
            print()
        }
    } catch {
        print("❌ Search failed: \(error)")
    }
}

#Playground("Unrestricted results (default)")
{
    print("\n📍 Searching for 'URLSession' (unrestricted - default) ...")
    let retriever = AppleDocsRetriever()
    do {
        let results = try await retriever.search(query: "URLSession")
        print("✅ Found \(results.count) results (showing all)\n")
    } catch {
        print("❌ Search failed: \(error)")
    }
}

#Playground("Search and fetch Array")
{
    print("Search and fetch 'Array'...")
    let retriever = AppleDocsRetriever()
    do {
        print("Searching for 'Array' ...")
        if let content = try await retriever.searchAndFetch(query: "Array") {
            print("✅ Success!")
            print("📄 Title: \(content.searchResult.title)")
            print("🔗 URL: \(content.searchResult.url.absoluteString)")
            print("📏 Markdown length: \(content.markdown.count) characters")
            print("\n📖 First 500 characters of Markdown:")
            print("-" * 50)
            print(String(content.markdown.prefix(500)))
            print("... ")
            print()
        } else {
            print("⚠️ No results found")
        }
    } catch {
        print("❌ Fetch failed: \(error)")
    }
}

#Playground("Test specific Swift type Double")
{
    print("Fetching 'Double' documentation...")
    let retriever = AppleDocsRetriever()
    do {
        let results = try await retriever.search(query: "Double swift")
        if let firstResult = results.first {
            let content = try await retriever.fetch(firstResult)
            print("✅ Fetched: \(content.searchResult.title)")
            print("\n📄 Markdown preview:")
            print("-" * 50)
            
            // Show the first 10 lines
            let lines = content.markdown.split(separator: "\n", maxSplits: 10)
            for line in lines {
                print(line)
            }
            print("...")
            print()
        }
    } catch {
        print("❌ Failed: \(error)")
    }
    
    print("-" * 50)
    print()
}

#Playground("Caching")
{
    print("Testing cache performance...")

    let cache = InMemoryKnowledgeCache(maxAge: 60)
    let cachedRetriever = AppleDocsRetriever(cache: cache)

    do {
        // First, search once to get a SearchResult
        print("🔍 Searching for 'Array' (once)...")
        let results = try await cachedRetriever.search(query: "Array")
        guard let firstResult = results.first else {
            print("❌ No results found")
            return
        }
        print("   Found:  \(firstResult.title)")

        // First fetch - should hit network
        print("\n⏱️  First fetch (network)...")
        let start1 = Date()
        let content1 = try await cachedRetriever.fetch(firstResult)
        let duration1 = Date().timeIntervalSince(start1)
        print("   Took: \(String(format: "%.3f", duration1)) seconds")
        print("   Markdown length: \(content1.markdown.count) chars")

        // Second fetch - should hit cache (same SearchResult)
        print("\n⏱️  Second fetch (should use cache)...")
        let start2 = Date()
        let content2 = try await cachedRetriever.fetch(firstResult)
        let duration2 = Date().timeIntervalSince(start2)
        print("   Took: \(String(format: "%.3f", duration2)) seconds")
        print("   Markdown length: \(content2.markdown.count) chars")

        if duration2 < duration1 {
            let speedup = duration1 / duration2
            print("\n🎉 Cache speedup: \(String(format: "%.1f", speedup))x faster!")
        } else {
            print("\n⚠️  Cache didn't speed things up (might need to check implementation)")
        }
        print()
    } catch {
        print("❌ Cache test failed: \(error)")
    }
}

#Playground("Search for SwiftUI types")
{
    print("Exploring SwiftUI types...")
    let retriever = AppleDocsRetriever()
    let swiftUIQueries = ["View", "Button", "Text", "VStack"]
    
    for query in swiftUIQueries {
        do {
            let results = try await retriever.search(query: "\(query) SwiftUI")
            if let first = results.first {
                print("📱 \(query) → \(first.title)")
            }
        } catch {
            print("❌ \(query) → Error: \(error)")
        }
    }
}

