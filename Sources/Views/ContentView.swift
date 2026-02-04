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
                        LazyVStack(spacing: 0) {
                            ForEach(filteredItems) { item in
                                ClipboardItemRow(item: item)
                                    .padding(.vertical, 4)
                            }
                        }
                        .padding(.horizontal)
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
            SettingsView()
                .frame(minWidth: 560, minHeight: 440)
                .presentationBackground(ThemeManager.shared.surface)
        }
    }

    private var filteredItems: [ClipboardItem] {
        if searchText.isEmpty {
            return clipboardMonitor.capturedItems
        }
        return clipboardMonitor.capturedItems.filter { item in
            item.content.localizedCaseInsensitiveContains(searchText)
        }
    }
}

#Preview {
    ContentView()
}
