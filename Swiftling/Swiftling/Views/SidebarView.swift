//
//  SidebarView.swift
//  Swiftling
//
//  Created by Claude Code on 09.11.25.
//

import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText: String = ""

    var body: some View {
        @Bindable var appState = appState

        List {
            Section("Knowledge Sources") {
                Toggle("Apple Developer Docs", isOn: binding(for: "apple-docs"))

                Toggle("HackingWithSwift", isOn: .constant(false))
                    .disabled(true)
                    .foregroundStyle(.secondary)

                Toggle("GitHub Repositories", isOn: .constant(false))
                    .disabled(true)
                    .foregroundStyle(.secondary)
            }

            Section("Search") {
                HStack {
                    TextField("Ask a question...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            performSearch()
                        }

                    Button(action: performSearch) {
                        Label("Go", systemImage: "arrow.right.circle.fill")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(searchText.isEmpty || appState.isSearching)
                }

                if appState.isSearching {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Searching...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !appState.currentQuery.isEmpty {
                Section("Current Query") {
                    HStack {
                        Text(appState.currentQuery)
                            .font(.body)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button(action: {
                            appState.clearSearch()
                            searchText = ""
                        }) {
                            Label("Clear", systemImage: "xmark.circle.fill")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .navigationTitle("Swiftling")
        #if os(macOS)
        .navigationSubtitle("\(appState.searchResults.count) results")
        #endif
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    appState.clearSearch()
                    searchText = ""
                }) {
                    Label("Clear All", systemImage: "trash")
                }
                .disabled(appState.searchResults.isEmpty && appState.currentQuery.isEmpty)
            }
        }
    }

    // MARK: - Helper Methods

    private func binding(for source: String) -> Binding<Bool> {
        Binding(
            get: { appState.enabledSources.contains(source) },
            set: { enabled in
                if enabled {
                    appState.enabledSources.insert(source)
                } else {
                    appState.enabledSources.remove(source)
                }
            }
        )
    }

    private func performSearch() {
        guard !searchText.isEmpty else { return }
        Task {
            await appState.performSearch(query: searchText)
        }
    }
}

#Preview {
    @Previewable @State var appState = AppState()

    NavigationStack {
        SidebarView()
            .environment(appState)
    }
}
