//
//  ResultsListView.swift
//  Swiftling
//
//  Created by Claude Code on 09.11.25.
//

import SwiftUI

struct ResultsListView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

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
            } else if appState.searchResults.isEmpty {
                ContentUnavailableView(
                    "No Search Yet",
                    systemImage: "magnifyingglass",
                    description: Text("Enter a query in the sidebar to search documentation")
                )
            } else {
                resultsList
            }
        }
        .navigationTitle("Results")
        #if os(macOS)
        .navigationSubtitle("\(appState.searchResults.count) found")
        #endif
    }

    private var resultsList: some View {
        @Bindable var appState = appState

        return List(appState.searchResults, selection: $appState.selectedResult) { result in
            ResultCardView(result: result)
                .tag(result)
        }
        .listStyle(.plain)
    }

    private var sourceNames: String {
        appState.enabledSources
            .map { $0.replacingOccurrences(of: "-", with: " ").capitalized }
            .joined(separator: ", ")
    }
}

// MARK: - Result Card View

struct ResultCardView: View {
    let result: SearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            Text(result.title)
                .font(.headline)
                .lineLimit(2)

            // Summary
            if let summary = result.summary, !summary.isEmpty {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            // Breadcrumbs
            if !result.breadcrumbs.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Text(result.breadcrumbs.joined(separator: " › "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            // Metadata row
            HStack(spacing: 8) {
                // Source badge
                Label(result.sourceIdentifier.replacingOccurrences(of: "-", with: " ").capitalized,
                      systemImage: sourceIcon(for: result.sourceIdentifier))
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .cornerRadius(4)

                // Result type badge
                if let resultType = result.resultType {
                    Text(resultType)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.green.opacity(0.1))
                        .foregroundStyle(.green)
                        .cornerRadius(4)
                }

                Spacer()

                // Relevance score
                if let score = result.relevanceScore {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                        Text(String(format: "%.1f%%", score * 100))
                            .font(.caption)
                    }
                    .foregroundStyle(.orange)
                }
            }

            // Tags
            if !result.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(result.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.gray.opacity(0.1))
                                .foregroundStyle(.secondary)
                                .cornerRadius(3)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func sourceIcon(for source: String) -> String {
        switch source {
        case "apple-docs":
            return "apple.logo"
        case "hackingwithswift":
            return "book.fill"
        case "github":
            return "chevron.left.forwardslash.chevron.right"
        default:
            return "doc.fill"
        }
    }
}

#Preview("Results List") {
    let appState = AppState()
    appState.searchResults = [
        SearchResult(
            title: "Array",
            summary: "An ordered, random-access collection.",
            url: URL(string: "https://developer.apple.com/documentation/swift/array")!,
            sourceIdentifier: "apple-docs",
            breadcrumbs: ["Swift", "Collections"],
            tags: ["Swift", "Collections", "Array"],
            resultType: "documentation",
            relevanceScore: 0.95
        ),
        SearchResult(
            title: "Dictionary",
            summary: "A collection whose elements are key-value pairs.",
            url: URL(string: "https://developer.apple.com/documentation/swift/dictionary")!,
            sourceIdentifier: "apple-docs",
            breadcrumbs: ["Swift", "Collections"],
            tags: ["Swift", "Collections", "Dictionary"],
            resultType: "documentation",
            relevanceScore: 0.87
        )
    ]

    return NavigationStack {
        ResultsListView()
            .environment(appState)
    }
}
