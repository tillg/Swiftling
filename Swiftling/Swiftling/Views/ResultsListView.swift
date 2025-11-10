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

        return VStack(spacing: 0) {
            // Rerank button
            rerankButton
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Partial failure warnings
            if !appState.sourceErrors.isEmpty {
                sourceWarnings
            }

            // Results list
            List(appState.searchResults, selection: $appState.selectedResult) { result in
                ResultCardView(result: result)
                    .tag(result)
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private var sourceWarnings: some View {
        VStack(spacing: 8) {
            ForEach(Array(appState.sourceErrors.keys.sorted()), id: \.self) { source in
                if let error = appState.sourceErrors[source] {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(sourceDisplayName(source))
                                .font(.caption)
                                .fontWeight(.medium)

                            Text(errorMessage(error))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func sourceDisplayName(_ identifier: String) -> String {
        switch identifier {
        case "apple-docs":
            return "Apple Developer Documentation"
        case "hackingwithswift":
            return "Hacking with Swift"
        case "github":
            return "GitHub"
        default:
            return identifier.replacingOccurrences(of: "-", with: " ").capitalized
        }
    }

    private func errorMessage(_ error: Error) -> String {
        if let retrieverError = error as? KnowledgeRetrieverError {
            switch retrieverError {
            case .noResults:
                return "No results found"
            case .networkError:
                return "Network error"
            case .parsingError:
                return "Failed to parse results"
            default:
                return error.localizedDescription
            }
        }
        return error.localizedDescription
    }

    private var rerankButton: some View {
        Button(action: {
            Task {
                await appState.performRerank()
            }
        }) {
            HStack(spacing: 8) {
                switch appState.rerankButtonState {
                case .ready:
                    Image(systemName: "sparkles")
                    Text("Rerank with AI")

                case .reranking:
                    ProgressView()
                        .controlSize(.small)
                    Text("Reranking...")

                case .completed:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Reranked")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(appState.searchResults.isEmpty || appState.rerankButtonState != .ready)
        .animation(.easeInOut, value: appState.rerankButtonState)
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
            // Title with movement indicator
            HStack {
                Text(result.title)
                    .font(.headline)
                    .lineLimit(2)

                Spacer()

                // Movement indicator
                if let delta = result.movementDelta {
                    movementIndicator(delta: delta)
                }
            }

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
                // AI Reranked badge
                if result.isReranked {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("AI Reranked")
                    }
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.purple.opacity(0.1))
                    .foregroundStyle(.purple)
                    .cornerRadius(4)
                }

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

    @ViewBuilder
    private func movementIndicator(delta: Int) -> some View {
        if delta > 0 {
            // Moved up
            let arrows = delta >= 3 ? "↑↑" : "↑"
            Text(arrows)
                .font(.caption)
                .foregroundStyle(.green)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(.green.opacity(0.1))
                .cornerRadius(3)
        } else if delta < 0 {
            // Moved down
            Text("↓")
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(.orange.opacity(0.1))
                .cornerRadius(3)
        }
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
