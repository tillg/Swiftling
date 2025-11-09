//
//  SupportViews.swift
//  Swiftling
//
//  Created by Claude Code on 09.11.25.
//

import SwiftUI

// MARK: - Loading View

struct LoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)

            Text(message)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Error View

struct ErrorView: View {
    let error: Error
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Something Went Wrong")
                .font(.title2)
                .fontWeight(.semibold)

            Text(error.localizedDescription)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Try Again") {
                retryAction()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    var body: some View {
        ContentUnavailableView(
            "No Results Found",
            systemImage: "magnifyingglass",
            description: Text("Try a different search query or enable more knowledge sources")
        )
    }
}

// MARK: - Placeholder View

struct PlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "Select a Result",
            systemImage: "doc.text.magnifyingglass",
            description: Text("Choose a search result from the list to view its documentation")
        )
    }
}

// MARK: - Previews

#Preview("Loading View") {
    LoadingView(message: "Searching Apple Developer Docs...")
}

#Preview("Error View") {
    ErrorView(error: NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network connection lost"])) {
        print("Retry tapped")
    }
}

#Preview("Empty State View") {
    EmptyStateView()
}

#Preview("Placeholder View") {
    PlaceholderView()
}
