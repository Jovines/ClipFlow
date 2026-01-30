import SwiftUI

struct ContentView: View {
    @State private var clipboardHistory: [ClipboardItem] = []
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                SearchBar(text: $searchText)
                    .padding()

                // History list
                if clipboardHistory.isEmpty {
                    EmptyStateView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredItems) { item in
                                ClipboardItemRow(item: item)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("ClipFlow")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {}) {
                        Image(systemName: "gear")
                    }
                    .help("Settings")
                }
            }
        }
        .onAppear {
            loadClipboardHistory()
        }
    }

    private var filteredItems: [ClipboardItem] {
        if searchText.isEmpty {
            return clipboardHistory
        }
        return clipboardHistory.filter { item in
            item.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func loadClipboardHistory() {
        // TODO: Load from Core Data
        clipboardHistory = []
    }
}

#Preview {
    ContentView()
}
