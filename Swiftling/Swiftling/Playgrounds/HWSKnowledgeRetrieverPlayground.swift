//
//  HWSKnowledgeRetrieverPlayground.swift
//  Swiftling
//
//  Created by Claude Code on 09.11.25.
//

import Foundation
import Playgrounds

// Helper to repeat strings
private func * (string: String, count: Int) -> String {
    String(repeating: string, count: count)
}

#Playground("Direct Fetch Test - Article")
{
    let retriever = HWSKnowledgeRetriever()

    // Create a search result with a known HWS article URL
    let knownURL = URL(string: "https://www.hackingwithswift.com/swift/5.9/macros")!
    let searchResult = SearchResult(
        title: "Macros – available from Swift 5.9",
        summary: "",
        url: knownURL,
        sourceIdentifier: "hackingwithswift"
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

        // Check if cleanup worked (should not contain navigation/footer)
        let hasNavigation = content.markdown.contains("SUBSCRIBE")
        let hasFooter = content.markdown.contains("Link copied to your pasteboard")
        print("\n🧹 Cleanup check:")
        print("   Navigation removed: \(hasNavigation ? "❌ NO" : "✅ YES")")
        print("   Footer removed: \(hasFooter ? "❌ NO" : "✅ YES")")
    } catch {
        print("❌ Fetch failed: \(error)")
        if let retrievalError = error as? KnowledgeRetrieverError {
            print("   Details: \(retrievalError.errorDescription ?? "")")
        }
    }
}

#Playground("Search for 'protocols'")
{
    let retriever = HWSKnowledgeRetriever()

    // Test: Search with limited results
    print("📍 Searching for 'protocols' (limit: 10) ...")
    do {
        let results = try await retriever.search(query: "protocols", maxResults: 10)
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
        if let retrievalError = error as? KnowledgeRetrieverError {
            print("   Details: \(retrievalError.errorDescription ?? "")")
        }
    }
}

#Playground("Search and Fetch 'SwiftUI'")
{
    print("Search and fetch 'SwiftUI'...")
    let retriever = HWSKnowledgeRetriever()
    do {
        print("Searching for 'SwiftUI' ...")
        if let content = try await retriever.searchAndFetch(query: "SwiftUI") {
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
        if let retrievalError = error as? KnowledgeRetrieverError {
            print("   Details: \(retrievalError.errorDescription ?? "")")
        }
    }
}

#Playground("Test Example Code Search")
{
    print("Searching for example code: 'How to use closures'...")
    let retriever = HWSKnowledgeRetriever()
    do {
        let results = try await retriever.search(query: "how to use closures", maxResults: 5)
        print("✅ Found \(results.count) results\n")

        for (index, result) in results.enumerated() {
            print("[\(index + 1)] \(result.title)")
            if let type = result.resultType {
                print("    Type: \(type)")
            }
            print("    URL: \(result.url.path)")
            print()
        }

        // Try to fetch the first result if it's example-code
        if let first = results.first, first.resultType == "example-code" {
            print("📥 Fetching first example code result...")
            let content = try await retriever.fetch(first)
            print("✅ Fetched: \(content.searchResult.title)")
            print("\n📄 Markdown preview (first 400 chars):")
            print("-" * 50)
            print(String(content.markdown.prefix(400)))
            print("...")
            print()
        }
    } catch {
        print("❌ Failed: \(error)")
    }
}

#Playground("Test Different Content Types")
{
    print("Testing different HWS content types...")
    let retriever = HWSKnowledgeRetriever()

    let queries = [
        ("SwiftUI tutorial", "article/tutorial"),
        ("UIView example", "example-code"),
        ("Swift 6 changes", "swift-version"),
        ("100 days of swift", "100-days")
    ]

    for (query, expectedType) in queries {
        do {
            print("\n🔍 Query: '\(query)'")
            let results = try await retriever.search(query: query, maxResults: 3)
            if let first = results.first {
                print("   ✅ \(first.title)")
                if let type = first.resultType {
                    print("   📦 Type: \(type)")
                }
            } else {
                print("   ⚠️  No results")
            }
        } catch {
            print("   ❌ Error: \(error)")
        }
    }
}

#Playground("Markdown Cleanup Verification")
{
    print("Testing markdown cleanup quality...")
    let retriever = HWSKnowledgeRetriever()

    do {
        // Search for a common article
        let results = try await retriever.search(query: "what is a protocol", maxResults: 1)
        guard let first = results.first else {
            print("❌ No results found")
            return
        }

        print("📄 Fetching: \(first.title)")
        let content = try await retriever.fetch(first)

        // Check for common boilerplate that should be removed
        let boilerplatePatterns = [
            ("Navigation menu", "Forums"),
            ("Footer store link", "Click here to visit the Hacking with Swift store"),
            ("Login prompt", "Log in or create account"),
            ("Subscribe text", "Subscribe to my monthly newsletter"),
            ("Social links", "@twostraws"),
            ("Rating widget", "Was this page useful"),
            ("Buy books", "BUY OUR BOOKS"),
            ("Pasteboard message", "Link copied to your pasteboard")
        ]

        print("\n🧹 Cleanup verification:")
        var cleanCount = 0
        for (name, pattern) in boilerplatePatterns {
            let removed = !content.markdown.contains(pattern)
            print("   \(name): \(removed ? "✅ Removed" : "❌ Still present")")
            if removed { cleanCount += 1 }
        }

        let cleanPercentage = (Double(cleanCount) / Double(boilerplatePatterns.count)) * 100
        print("\n📊 Cleanup score: \(cleanCount)/\(boilerplatePatterns.count) (\(String(format: "%.0f", cleanPercentage))%)")

        // Show some sample content
        print("\n📖 Content sample (first 300 chars):")
        print("-" * 50)
        print(String(content.markdown.prefix(300)))
        print("...")

    } catch {
        print("❌ Test failed: \(error)")
    }
}

#Playground("Test Cache Performance")
{
    print("Testing cache performance...")
    let retriever = HWSKnowledgeRetriever()

    do {
        // First, search once to get a SearchResult
        print("🔍 Searching for 'Swift optionals' (once)...")
        let results = try await retriever.search(query: "Swift optionals", maxResults: 1)
        guard let firstResult = results.first else {
            print("❌ No results found")
            return
        }
        print("   Found: \(firstResult.title)")

        // First fetch - should hit network
        print("\n⏱️  First fetch (network)...")
        let start1 = Date()
        let content1 = try await retriever.fetch(firstResult)
        let duration1 = Date().timeIntervalSince(start1)
        print("   Took: \(String(format: "%.3f", duration1)) seconds")
        print("   Markdown length: \(content1.markdown.count) chars")

        // Second fetch - should hit cache
        print("\n⏱️  Second fetch (should use cache)...")
        let start2 = Date()
        let content2 = try await retriever.fetch(firstResult)
        let duration2 = Date().timeIntervalSince(start2)
        print("   Took: \(String(format: "%.3f", duration2)) seconds")
        print("   Markdown length: \(content2.markdown.count) chars")

        if duration2 < duration1 {
            let speedup = duration1 / duration2
            print("\n🎉 Cache speedup: \(String(format: "%.1f", speedup))x faster!")
        } else {
            print("\n⚠️  Cache didn't speed things up significantly")
            print("   (First: \(String(format: "%.3f", duration1))s, Second: \(String(format: "%.3f", duration2))s)")
        }

        // Check cache size
        let cacheSize = await retriever.cacheSize()
        print("📦 Cache size: \(cacheSize) items")
        print()
    } catch {
        print("❌ Cache test failed: \(error)")
    }
}

#Playground("Popular Swift Topics")
{
    print("Searching for popular Swift topics on HWS...")
    let retriever = HWSKnowledgeRetriever()
    let topics = [
        "async await",
        "property wrappers",
        "generics",
        "protocols",
        "combine"
    ]

    for topic in topics {
        do {
            let results = try await retriever.search(query: topic, maxResults: 1)
            if let first = results.first {
                print("📚 \(topic.capitalized) → \(first.title)")
            } else {
                print("📚 \(topic.capitalized) → No results")
            }
        } catch {
            print("📚 \(topic.capitalized) → Error: \(error.localizedDescription)")
        }
    }
    print()
}

#Playground("URL Pattern Verification")
{
    print("Testing URL pattern recognition...")
    let retriever = HWSKnowledgeRetriever()

    let testQueries = [
        "SwiftUI tutorial",  // Should find articles
        "array methods",     // Should find example-code
        "swift 6"           // Should find swift-version content
    ]

    for query in testQueries {
        do {
            print("\n🔍 '\(query)':")
            let results = try await retriever.search(query: query, maxResults: 3)

            for (index, result) in results.enumerated() {
                let urlPath = result.url.path
                let contentType = result.resultType ?? "unknown"
                print("   [\(index + 1)] Type: \(contentType)")
                print("       Path: \(urlPath)")
            }
        } catch {
            print("   ❌ Error: \(error.localizedDescription)")
        }
    }
}
