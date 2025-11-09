//
//  DetailView.swift
//  Swiftling
//
//  Created by Claude Code on 09.11.25.
//

import SwiftUI

struct DetailView: View {
    @Environment(AppState.self) private var appState
    let result: SearchResult

    @State private var documentContent: DocumentContent?
    @State private var isLoading: Bool = true
    @State private var loadError: Error?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    // Title
                    Text(result.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    // Breadcrumbs
                    if !result.breadcrumbs.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)

                            Text(result.breadcrumbs.joined(separator: " › "))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Metadata badges
                    HStack(spacing: 8) {
                        // Source
                        Label(result.sourceIdentifier.replacingOccurrences(of: "-", with: " ").capitalized,
                              systemImage: sourceIcon(for: result.sourceIdentifier))
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .cornerRadius(6)

                        // Result type
                        if let resultType = result.resultType {
                            Text(resultType)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.green.opacity(0.1))
                                .foregroundStyle(.green)
                                .cornerRadius(6)
                        }

                        Spacer()

                        // Open in browser button
                        Link(destination: result.url) {
                            Label("Open in Browser", systemImage: "safari")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }

                    // Tags
                    if !result.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(result.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.gray.opacity(0.1))
                                        .foregroundStyle(.secondary)
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }
                .padding()
                #if os(iOS)
                .background(Color(uiColor: .secondarySystemBackground))
                #else
                .background(Color(nsColor: .controlBackgroundColor))
                #endif
                .cornerRadius(12)

                Divider()

                // Content
                Group {
                    if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Loading documentation...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let error = loadError {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundStyle(.orange)

                            Text("Failed to load content")
                                .font(.headline)

                            Text(error.localizedDescription)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            Button("Retry") {
                                loadContent()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let content = documentContent {
                        VStack(alignment: .leading, spacing: 12) {
                            // Markdown content (stripped of frontmatter and formatted)
                            FullMarkdownView(markdown: MarkdownUtilities.stripFrontmatter(content.markdown))

                            Divider()

                            // Metadata footer
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Document Information")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)

                                HStack {
                                    Label("Fetched", systemImage: "clock")
                                    Text(content.fetchedAt, style: .relative)
                                        .foregroundStyle(.secondary)
                                }
                                .font(.caption)

                                if !result.metadata.isEmpty {
                                    ForEach(Array(result.metadata.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                                        HStack {
                                            Text("\(key):")
                                                .fontWeight(.medium)
                                            Text(value)
                                                .foregroundStyle(.secondary)
                                        }
                                        .font(.caption)
                                    }
                                }
                            }
                            .padding()
                            #if os(iOS)
                            .background(Color(uiColor: .secondarySystemBackground))
                            #else
                            .background(Color(nsColor: .controlBackgroundColor))
                            #endif
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(result.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task(id: result.id) {
            loadContent()
        }
    }

    // MARK: - Helper Methods

    private func loadContent() {
        isLoading = true
        loadError = nil

        Task {
            do {
                // Fetch content using the appropriate retriever
                let retriever = retrieverForSource(result.sourceIdentifier)
                let content = try await retriever.fetch(result)

                await MainActor.run {
                    self.documentContent = content
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.loadError = error
                    self.isLoading = false
                }
            }
        }
    }

    private func retrieverForSource(_ sourceIdentifier: String) -> any KnowledgeRetriever {
        switch sourceIdentifier {
        case "apple-docs":
            return AppleDocsRetriever()
        // TODO: Add other retrievers when implemented
        default:
            return AppleDocsRetriever()
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

#Preview {
    @Previewable @State var appState = AppState()

    let sampleResult = SearchResult(
        title: "Array",
        summary: "An ordered, random-access collection.",
        url: URL(string: "https://developer.apple.com/documentation/swift/array")!,
        sourceIdentifier: "apple-docs",
        breadcrumbs: ["Swift", "Collections"],
        tags: ["Swift", "Collections", "Array"],
        resultType: "documentation",
        relevanceScore: 0.95,
        metadata: ["Language": "Swift", "Framework": "Swift Standard Library"]
    )

    NavigationStack {
        DetailView(result: sampleResult)
            .environment(appState)
    }
}
