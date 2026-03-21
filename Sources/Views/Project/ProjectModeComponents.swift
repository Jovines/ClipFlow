// swiftlint:disable file_length
import AppKit
import MarkdownView
import SwiftUI

struct ProjectModeHeader: View {
    let project: Project
    let rawInputCount: Int
    let unanalyzedCount: Int
    let isAnalyzing: Bool
    let isResettingAnalysis: Bool
    let errorMessage: String?
    let isAIConfigured: Bool
    let onExit: () -> Void
    let onExport: () -> Void
    let onAnalyze: () -> Void
    let onResetAnalysis: () -> Void
    let onOpenPromptSettings: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(Color.flexokiAccent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.flexokiText)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                if isAIConfigured && unanalyzedCount > 0 {
                    Button(action: onAnalyze) {
                        HStack(spacing: 4) {
                            if isAnalyzing {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 12, height: 12)
                                Text("Analyzing...".localized())
                            } else {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 10))
                                Text("Incremental Analysis (%1$d)".localized(unanalyzedCount))
                            }
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(isAnalyzing)
                }

                if rawInputCount > 0 && !isAnalyzing && !isResettingAnalysis {
                    Button(action: onResetAnalysis) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 10))
                            Text("Regenerate".localized())
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundStyle(Color.flexokiOrange600)
                }

                if isResettingAnalysis {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                        Text("Resetting...".localized())
                    }
                    .font(.caption)
                    .foregroundStyle(Color.flexokiOrange600)
                }

                if !isAIConfigured {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.flexokiOrange600)
                    Text("AI Not Configured".localized())
                        .font(.caption)
                        .foregroundStyle(Color.flexokiOrange600)
                } else if let error = errorMessage {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.flexokiRed600)
                    Text("Operation Failed".localized())
                        .font(.caption)
                        .foregroundStyle(Color.flexokiRed600)
                        .help(error)
                } else if rawInputCount > 0 {
                    Image(systemName: "doc.text")
                        .font(.system(size: 10))
                        .foregroundStyle(ThemeManager.shared.textSecondary)
                    Text("%1$d Materials".localized(rawInputCount))
                        .font(.caption)
                        .foregroundStyle(ThemeManager.shared.textSecondary)
                }

                Divider()
                    .frame(height: 16)
                    .background(ThemeManager.shared.border)

                Button(action: onExport) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .help("Export Project".localized())

                Button(action: onOpenPromptSettings) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .help("AI Prompt Settings".localized())

                Divider()
                    .frame(height: 16)
                    .background(ThemeManager.shared.border)

                Button(action: onExit) {
                    Label("Exit Project".localized(), systemImage: "xmark.circle")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(ThemeManager.shared.surface)
    }
}

struct CognitionDocumentView: View {
    let cognition: ProjectCognition

    var body: some View {
        ScrollView {
            MarkdownView(cognition.content)
                .font(.system(size: 14), for: .body)
                .font(.system(size: 22, weight: .bold), for: .h1)
                .font(.system(size: 18, weight: .semibold), for: .h2)
                .font(.system(size: 16, weight: .semibold), for: .h3)
                .tint(Color.flexokiAccent, for: .inlineCodeBlock)
                .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThemeManager.shared.background)
    }
}

struct RawInputsList: View {
    let inputs: [(input: ProjectRawInput, item: ClipboardItem?)]
    let onDelete: (UUID) -> Void
    let onEdit: (UUID, String, String?) -> Void

    var body: some View {
        List {
            ForEach(inputs, id: \.input.id) { tuple in
                RawInputRow(
                    input: tuple.input,
                    item: tuple.item,
                    onDelete: { onDelete(tuple.input.id) },
                    onEdit: { content, sourceContext in
                        if let item = tuple.item {
                            onEdit(item.id, content, sourceContext)
                        }
                    }
                )
            }
        }
        .listStyle(.plain)
    }
}

struct RawInputRow: View {
    let input: ProjectRawInput
    let item: ClipboardItem?
    let onDelete: () -> Void
    let onEdit: (String, String?) -> Void

    @State private var isEditing = false
    @State private var editedContent: String = ""
    @State private var editedSourceContext: String = ""
    @State private var showDeleteConfirm = false
    @State private var isHovered = false

    private var backgroundColor: Color {
        if isEditing {
            return ThemeManager.shared.surfaceElevated
        }
        if input.isAnalyzed {
            return Color.flexokiBase100.opacity(0.3)
        }
        return isHovered ? Color.flexokiBase100.opacity(0.5) : Color.clear
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isEditing {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Source:".localized())
                            .font(.caption)
                            .foregroundStyle(ThemeManager.shared.textSecondary)
                        TextField("Source Context Placeholder".localized(), text: $editedSourceContext)
                            .font(.caption)
                            .textFieldStyle(.roundedBorder)
                    }

                    TextEditor(text: $editedContent)
                        .font(.system(size: 11))
                        .frame(minHeight: 60)
                        .frame(maxHeight: 120)
                        .scrollContentBackground(.hidden)
                        .background(ThemeManager.shared.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(ThemeManager.shared.borderSubtle, lineWidth: 1)
                        )

                    HStack {
                        Button("Cancel".localized()) {
                            isEditing = false
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                        .font(.caption)
                        .foregroundStyle(ThemeManager.shared.textSecondary)

                        Spacer()

                        Button("Save".localized()) {
                            let context = editedSourceContext.isEmpty ? nil : editedSourceContext
                            onEdit(editedContent, context)
                            isEditing = false
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .font(.caption)
                    }
                }
            } else {
                HStack {
                    Text(input.sourceContext ?? "Unnamed".localized())
                        .font(.caption)
                        .foregroundStyle(Color.flexokiAccent)
                        .lineLimit(1)

                    Spacer()

                    Text(input.createdAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(ThemeManager.shared.textTertiary)
                }

                if let item = item {
                    Text(item.content)
                        .font(.system(size: 11))
                        .lineLimit(3)
                        .foregroundStyle(Color.flexokiText)
                }

                HStack {
                    if let item = item {
                        Button(action: {
                            editedContent = item.content
                            editedSourceContext = input.sourceContext ?? ""
                            isEditing = true
                        }) {
                            Image(systemName: "pencil")
                                .font(.caption2)
                                .foregroundStyle(ThemeManager.shared.textTertiary)
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                        .opacity(isHovered ? 1 : 0.6)
                    }

                    Spacer()

                    Button(action: { showDeleteConfirm = true }) {
                        Image(systemName: "trash")
                            .font(.caption2)
                            .foregroundStyle(Color.flexokiRed600.opacity(0.7))
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .opacity(isHovered ? 1 : 0.6)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(backgroundColor)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .alert("Confirm Delete".localized(), isPresented: $showDeleteConfirm) {
            Button("Cancel".localized(), role: .cancel) { }
            Button("Delete".localized(), role: .destructive) {
                onDelete()
            }
        } message: {
            Text("This material will be permanently deleted and cannot be recovered. Are you sure?".localized())
        }
    }
}

struct AnalyzingView: View {
    let progress: String

    var body: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("AI Analyzing...".localized())
                .font(.caption)
                .foregroundStyle(ThemeManager.shared.textSecondary)
            if !progress.isEmpty {
                Text(progress)
                    .font(.caption2)
                    .foregroundStyle(ThemeManager.shared.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThemeManager.shared.surface.opacity(0.5))
    }
}

struct EmptyCognitionState: View {
    let rawInputCount: Int
    let unanalyzedCount: Int
    let isAIConfigured: Bool
    let errorMessage: String?
    let isAnalyzing: Bool
    let onAnalyze: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            if !isAIConfigured {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.flexokiOrange600)

                Text("AI Service Not Configured".localized())
                    .font(.headline)
                    .foregroundStyle(Color.flexokiOrange600)

                Text("Please configure AI provider in settings to use project features".localized())
                    .font(.caption)
                    .foregroundStyle(ThemeManager.shared.textSecondary)
                    .multilineTextAlignment(.center)

                if rawInputCount > 0 {
                    Text("%1$d items collected, waiting for AI analysis".localized(rawInputCount))
                        .font(.caption2)
                        .foregroundStyle(ThemeManager.shared.textTertiary)
                        .padding(.top, 8)
                }
            } else if let error = errorMessage {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.flexokiRed600)

                Text("AI Analysis Failed".localized())
                    .font(.headline)
                    .foregroundStyle(Color.flexokiRed600)

                Text(error)
                    .font(.caption)
                    .foregroundStyle(ThemeManager.shared.textSecondary)
                    .multilineTextAlignment(.center)

                if rawInputCount > 0 {
                    Text("%1$d items collected".localized(rawInputCount))
                        .font(.caption2)
                        .foregroundStyle(ThemeManager.shared.textTertiary)
                        .padding(.top, 8)
                }
            } else if isAnalyzing {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.flexokiAccent.opacity(0.6))

                Text("%1$d items collected".localized(rawInputCount))
                    .font(.headline)
                    .foregroundStyle(Color.flexokiText)

                Text("AI is analyzing, please wait...".localized())
                    .font(.caption)
                    .foregroundStyle(ThemeManager.shared.textSecondary)
                    .multilineTextAlignment(.center)

                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.top, 8)
            } else if rawInputCount > 0 {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.flexokiAccent)

                Text("%1$d items collected".localized(rawInputCount))
                    .font(.headline)
                    .foregroundStyle(Color.flexokiText)

                if unanalyzedCount > 0 {
                    Text("%1$d items pending analysis".localized(unanalyzedCount))
                        .font(.caption)
                        .foregroundStyle(ThemeManager.shared.textSecondary)
                        .multilineTextAlignment(.center)

                    Button(action: onAnalyze) {
                        Label("Start Analysis".localized(), systemImage: "wand.and.stars")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .padding(.top, 12)
                }
            } else {
                Image(systemName: "doc.text")
                    .font(.system(size: 40))
                    .foregroundStyle(ThemeManager.shared.textTertiary)

                Text("No Materials".localized())
                    .font(.headline)
                    .foregroundStyle(Color.flexokiText)

                Text("Copy discussion to clipboard to share".localized())
                    .font(.caption)
                    .foregroundStyle(ThemeManager.shared.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct ExportProjectView: View {
    let project: Project
    let onDismiss: () -> Void

    @State private var includeRawInputs = true
    @State private var isExporting = false
    @State private var exportContent = ""

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Export Project".localized())
                    .font(.headline)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Toggle("Include Raw Materials".localized(), isOn: $includeRawInputs)
                .font(.system(size: 13))
                .onChange(of: includeRawInputs) { _ in
                    generateExport()
                }

            Divider()

            if !exportContent.isEmpty {
                TextEditor(text: .constant(exportContent))
                    .font(.system(size: 11, design: .monospaced))
                    .frame(height: 300)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(ThemeManager.shared.borderSubtle, lineWidth: 1)
                    )
            }

            HStack {
                Button("Close".localized()) {
                    onDismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button(action: copyToClipboard) {
                    if isExporting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Copy to Clipboard".localized(), systemImage: "doc.on.doc")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isExporting)
            }
        }
        .padding()
        .frame(width: 500, height: 450)
        .onAppear {
            generateExport()
        }
    }

    private func generateExport() {
        do {
            exportContent = try ProjectService.shared.exportProjectToMarkdown(
                projectId: project.id,
                includeRawInputs: includeRawInputs
            )
        } catch {
            exportContent = "Export Failed: %1$@".localized(error.localizedDescription)
        }
    }

    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(exportContent, forType: .string)
        onDismiss()
    }
}
