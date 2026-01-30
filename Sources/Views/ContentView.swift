import SwiftUI

struct ContentView: View {
    @StateObject private var clipboardMonitor = ClipboardMonitor.shared
    @State private var searchText = ""
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                SearchBar(text: $searchText)
                    .padding()

                // History list
                if filteredItems.isEmpty {
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
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                    }
                    .help("Settings")
                }
            }
        }
        .onAppear {
            clipboardMonitor.refresh()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(onClose: { showingSettings = false })
        }
    }

    private var filteredItems: [ClipboardItem] {
        if searchText.isEmpty {
            return clipboardMonitor.capturedItems
        }
        return clipboardMonitor.capturedItems.filter { item in
            item.content.localizedCaseInsensitiveContains(searchText) ||
            item.tags.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
}

#Preview {
    ContentView()
}
