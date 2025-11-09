//
//  ContentView.swift
//  Swiftling
//
//  Created by Till Gartner on 09.11.25.
//

import SwiftUI

struct ContentView: View {
    @State private var appState = AppState()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar (Column 1)
            SidebarView()
                .environment(appState)

        } content: {
            // Results List (Column 2)
            ResultsListView()
                .environment(appState)

        } detail: {
            // Detail View (Column 3)
            if let selectedResult = appState.selectedResult {
                DetailView(result: selectedResult)
                    .environment(appState)
            } else {
                PlaceholderView()
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

#Preview {
    ContentView()
}
