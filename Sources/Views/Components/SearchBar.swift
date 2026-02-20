import SwiftUI
import Combine

/// Enhanced SearchBar with debouncing and search result highlighting support
struct SearchBar: View {
    @Binding var text: String
    @State private var debouncedText: String = ""
    @State private var cancellables = Set<AnyCancellable>()
    var onDebouncedTextChange: ((String) -> Void)?
    var delay: TimeInterval = 0.3

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(ThemeManager.shared.textSecondary)

            TextField("Search...".localized(), text: $text)
                .textFieldStyle(.plain)
                .onChange(of: text) { _, newValue in
                    debounceText(newValue)
                }

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(ThemeManager.shared.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(ThemeManager.shared.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func debounceText(_ value: String) {
        debouncedText = value
        cancellables.removeAll()

        Just(value)
            .delay(for: .seconds(delay), scheduler: RunLoop.main)
            .sink { debouncedValue in
                onDebouncedTextChange?(debouncedValue)
            }
            .store(in: &cancellables)
    }
}

/// Search result item with highlighted matching text
struct HighlightedText: View {
    let fullText: String
    let searchText: String

    var body: some View {
        if searchText.isEmpty {
            Text(fullText)
        } else {
            Text(highlightedString)
        }
    }

    private var highlightedString: AttributedString {
        var attributedString = AttributedString(fullText)
        let lowercasedFull = fullText.lowercased()
        let lowercasedSearch = searchText.lowercased()

        var searchRange = lowercasedFull.range(of: lowercasedSearch)
        while let range = searchRange {
            if let attributedRange = Range(
                NSRange(range, in: fullText),
                in: attributedString
            ) {
                attributedString[attributedRange].backgroundColor = Color.accentColor.opacity(0.2)
            }
            let nextStart = range.upperBound
            if nextStart < lowercasedFull.endIndex {
                searchRange = lowercasedFull[nextStart...].range(of: lowercasedSearch)
            } else {
                searchRange = nil
            }
        }
        return attributedString
    }
}

/// Advanced search bar with filter options
struct AdvancedSearchBar: View {
    @Binding var text: String
    @Binding var selectedFilter: SearchFilter
    @State private var showFilters = false

    enum SearchFilter: String, CaseIterable {
        case all = "All"
        case text = "Text"
        case images = "Images"
        case tagged = "Tagged"

        var icon: String {
            switch self {
            case .all: return "tray.full"
            case .text: return "doc.text"
            case .images: return "photo"
            case .tagged: return "tag"
            }
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(ThemeManager.shared.textSecondary)

TextField("Search...".localized(), text: $text)
                    .textFieldStyle(.plain)

                if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ThemeManager.shared.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(ThemeManager.shared.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Menu {
                ForEach(SearchFilter.allCases, id: \.self) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Label(filter.rawValue.localized(), systemImage: filter.icon)
                        if selectedFilter == filter {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                Image(systemName: selectedFilter.icon)
                    .foregroundStyle(selectedFilter == .all ? ThemeManager.shared.textSecondary : ThemeManager.shared.accent)
                    .padding(10)
                    .background(ThemeManager.shared.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        SearchBar(text: .constant("test"))

        AdvancedSearchBar(
            text: .constant(""),
            selectedFilter: .constant(.all)
        )
    }
    .padding()
}
