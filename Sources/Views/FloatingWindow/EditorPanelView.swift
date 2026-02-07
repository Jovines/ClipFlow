import SwiftUI
import AppKit
import Foundation

struct EditorPanelView: View {
    @Binding var editContent: String
    @Binding var editingItem: ClipboardItem?
    let originalContent: String
    let onSave: () -> Void
    let onCancel: () -> Void
    let onReset: () -> Void

    private let editorWidth: CGFloat = 280
    private let maxCharacterCount = 10000

    private var characterCount: Int {
        editContent.count
    }

    var body: some View {
        VStack(spacing: 0) {
            editorHeader
            Divider()
            editorContent
            Divider()
            editorFooter
        }
        .frame(width: editorWidth, height: 480)
        .background(ThemeManager.shared.surface.opacity(0.95))
    }

    private var editorHeader: some View {
        HStack {
            Text("编辑记录")
                .font(.system(size: 13, weight: .medium))
            Spacer()
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(ThemeManager.shared.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 32)
        .padding(.horizontal, 12)
    }

    private var editorContent: some View {
        VStack(spacing: 0) {
            TextEditor(text: $editContent)
                .font(.system(size: 13))
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(Color.clear)

            HStack {
                Text("\(characterCount)/\(maxCharacterCount)")
                    .font(.caption)
                    .foregroundStyle(ThemeManager.shared.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
    }

    private var editorFooter: some View {
        HStack(spacing: 8) {
            Button(action: onReset) {
                Text("重置")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .disabled(editContent == originalContent)

            Spacer()

            Button(action: onCancel) {
                Text("取消")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)

            Button(action: onSave) {
                Text("保存")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .disabled(editContent.isEmpty || editContent == originalContent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
