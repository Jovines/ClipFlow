import SwiftUI

struct EmptyStateView: View {
    enum State {
        case history
        case noResults(query: String)
    }

    let state: State
    var onClearSearch: (() -> Void)? = nil

    private var iconName: String {
        switch state {
        case .history:
            return "doc.on.clipboard"
        case .noResults:
            return "magnifyingglass"
        }
    }

    private var titleText: String {
        switch state {
        case .history:
            return "No Clipboard History".localized()
        case .noResults:
            return "No Results".localized()
        }
    }

    private var subtitleText: String {
        switch state {
        case .history:
            return "Copy something to see it here".localized()
        case .noResults(let query):
            return "No items match \"%1$@\"".localized(query)
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(titleText)
                .font(.headline)

            Text(subtitleText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if case .noResults = state, let onClearSearch {
                Button("Clear Search".localized(), action: onClearSearch)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }
}

#Preview {
    EmptyStateView(state: .history)
}
