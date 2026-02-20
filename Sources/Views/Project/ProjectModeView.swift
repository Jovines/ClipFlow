import SwiftUI
import AppKit
import MarkdownView

struct ProjectModeView: View {
    let project: Project
    let onExit: () -> Void
    
    @ObservedObject private var projectService = ProjectService.shared
    @ObservedObject private var aiService = OpenAIService.shared
    @State private var cognition: ProjectCognition?
    @State private var rawInputs: [(input: ProjectRawInput, item: ClipboardItem?)] = []
    @State private var isAnalyzing = false
    @State private var analysisError: String? = nil
    @State private var showExportSheet = false
    @State private var showPromptSettings = false
    @State private var showResetConfirmation = false
    @State private var isResettingAnalysis = false
    @State private var refreshTimer: Timer? = nil
    @State private var leftPanelWidth: CGFloat = 420
    @State private var editingProject: Project?
    
    // Computed property to check if there are unanalyzed inputs
    private var unanalyzedCount: Int {
        rawInputs.filter { !$0.input.isAnalyzed }.count
    }

    private var analyzedCount: Int {
        rawInputs.filter { $0.input.isAnalyzed }.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            ProjectModeHeader(
                project: project,
                rawInputCount: rawInputs.count,
                unanalyzedCount: unanalyzedCount,
                isAnalyzing: isAnalyzing,
                isResettingAnalysis: isResettingAnalysis,
                errorMessage: analysisError,
                isAIConfigured: aiService.hasAnyConfiguredProvider,
                onExit: onExit,
                onExport: { showExportSheet = true },
                onAnalyze: performAnalysis,
                onResetAnalysis: { showResetConfirmation = true },
                onOpenPromptSettings: { editingProject = project }
            )
            .background(ThemeManager.shared.surface)
            
            Divider()
                .background(ThemeManager.shared.border)
            
            if let cognition = cognition {
                // Main Content - Custom Split View with hidden divider
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        // Left: Cognition Document
                        CognitionDocumentView(cognition: cognition)
                            .frame(width: leftPanelWidth)
                            .background(ThemeManager.shared.background)
                        
                        // Hidden Draggable Divider
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 4)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let newWidth = leftPanelWidth + value.translation.width
                                        leftPanelWidth = min(max(newWidth, 300), geometry.size.width - 200)
                                    }
                            )
                            .onHover { isHovered in
                                if isHovered {
                                    NSCursor.resizeLeftRight.set()
                                } else {
                                    NSCursor.arrow.set()
                                }
                            }
                        
                        // Right: Raw Inputs List
                        VStack(spacing: 0) {
                            // Header
                            HStack {
                            Text("Raw Materials (%1$d)".localized(rawInputs.count))
                                .font(.caption)
                                .foregroundStyle(ThemeManager.shared.textSecondary)
                                Spacer()
                                if analyzedCount > 0 {
                                Text("%1$d Analyzed".localized(analyzedCount))
                                    .font(.caption2)
                                    .foregroundStyle(ThemeManager.shared.textTertiary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(ThemeManager.shared.surfaceElevated)
                            
                            Divider()
                                .background(ThemeManager.shared.borderSubtle)
                            
                            RawInputsList(
                                inputs: rawInputs,
                                onDelete: deleteRawInput,
                                onEdit: updateItemAndSource
                            )
                            .background(ThemeManager.shared.surface)
                        }
                        .frame(minWidth: 180, minHeight: 360)
                        .background(ThemeManager.shared.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(ThemeManager.shared.border, lineWidth: 1)
                        )
                        .padding(.vertical, 8)
                        .padding(.trailing, 8)
                    }
                }
                .background(ThemeManager.shared.background)
            } else {
                // Empty State
                EmptyCognitionState(
                    rawInputCount: rawInputs.count,
                    unanalyzedCount: unanalyzedCount,
                    isAIConfigured: aiService.hasAnyConfiguredProvider,
                    errorMessage: analysisError,
                    isAnalyzing: isAnalyzing,
                    onAnalyze: performAnalysis
                )
                .background(ThemeManager.shared.background)
            }
        }
        .frame(minHeight: 440)
        .background(ThemeManager.shared.background)
        .onAppear {
            loadData()
            startRefreshTimer()
        }
        .onDisappear {
            stopRefreshTimer()
        }
        .sheet(isPresented: $showExportSheet) {
            ExportProjectView(project: project, onDismiss: { showExportSheet = false })
        }
        .sheet(item: $editingProject) { project in
            ProjectPromptSettingsView(project: .constant(project)) {
                checkAndTriggerAnalysis()
            }
        }
        .onChange(of: editingProject) { _, newValue in
            if newValue == nil {
                checkAndTriggerAnalysis()
            }
        }
        .alert("Re-analyze".localized(), isPresented: $showResetConfirmation) {
            Button("Cancel".localized(), role: .cancel) { }
            Button("Continue Analysis".localized(), role: .destructive) {
                performResetAnalysis()
            }
        } message: {
            Text("This will reset all materials' analysis status and regenerate the cognition document based on existing materials. Old versions will be preserved in history.".localized())
        }
    }
    
    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            loadData()
        }
    }
    
    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    @MainActor
    private func loadData() {
        do {
            print("[ProjectMode] 🔄 Loading data for project: \(project.id)")
            let newCognition = try projectService.fetchCurrentCognition(for: project.id)
            let newRawInputs = try projectService.fetchRawInputsWithItems(for: project.id)
            
            print("[ProjectMode] 📊 Loaded cognition: \(newCognition != nil ? "yes" : "no"), inputs: \(newRawInputs.count)")
            
            // Only update if data actually changed to avoid unnecessary UI refreshes
            let cognitionChanged = (self.cognition?.id != newCognition?.id) ||
                                  (self.cognition?.createdAt != newCognition?.createdAt)
            let inputsChanged = self.rawInputs.count != newRawInputs.count ||
                                Set(self.rawInputs.map { $0.input.id }) != Set(newRawInputs.map { $0.input.id }) ||
                                zip(self.rawInputs, newRawInputs).contains { $0.input.sourceContext != $1.input.sourceContext }
            
            if cognitionChanged || inputsChanged {
                self.cognition = newCognition
                self.rawInputs = newRawInputs
                print("[ProjectMode] ✅ UI updated with new data (changed: cognition=\(cognitionChanged), inputs=\(inputsChanged))")
            } else {
                print("[ProjectMode] ⏭️ Data unchanged, skipping UI update")
            }
        } catch {
            print("[ProjectMode] ❌ Failed to load data: \(error)")
        }
    }
    
    private func deleteRawInput(id: UUID) {
        do {
            try projectService.deleteRawInput(id: id)
            print("[ProjectMode] ✅ Deleted raw input: \(id)")
            loadData()
        } catch {
            print("[ProjectMode] ❌ Failed to delete raw input: \(error)")
        }
    }
    
    private func checkAndTriggerAnalysis() {
        guard unanalyzedCount > 0 else { return }
        
        if let updatedProject = projectService.projects.first(where: { $0.id == project.id }) {
            if updatedProject.selectedPromptTemplateId != project.selectedPromptTemplateId {
                print("[ProjectMode] Template changed, triggering analysis...")
                performAnalysis()
            }
        }
    }
    
    private func updateItemAndSource(itemId: UUID, content: String, sourceContext: String?) {
        do {
            try DatabaseManager.shared.updateItemContent(id: itemId, content: content)
            
            if let tuple = rawInputs.first(where: { $0.item?.id == itemId }) {
                try projectService.updateRawInputSourceContext(id: tuple.input.id, sourceContext: sourceContext)
            }
            
            print("[ProjectMode] ✅ Updated item and source: \(itemId)")
            loadData()
        } catch {
            print("[ProjectMode] ❌ Failed to update item and source: \(error)")
        }
    }
    
    private func sendNotification(projectName: String) {
        let notification = NSUserNotification()
        notification.title = "AI Analysis Complete".localized()
        notification.informativeText = "AI analysis for project \"%1$@\" is complete".localized(projectName)
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    private func formatErrorMessage(_ error: Error) -> String {
        let message = error.localizedDescription
        
            if message.contains("API") || message.contains("APIKey") || message.contains("not configured") {
                return "AI service is not configured or invalid. Please check your API Key in settings.".localized()
            }
            
            if message.contains("network") || message.contains("Connection") || message.contains("timeout") {
                return "Network connection failed. Please check your network settings and try again.".localized()
            }
            
            if message.contains("rate limit") || message.contains("quota") {
                return "API rate limit reached. Please wait a moment or upgrade your quota.".localized()
            }
            
            if message.contains("invalid request") || message.contains("bad request") {
                return "Invalid request parameters. Please check your AI provider settings.".localized()
            }
            
            if message.contains("model") || message.contains("model not found") {
                return "AI model does not exist. Please check the model name in your settings.".localized()
            }
        
        return message
    }

    private func performAnalysis() {
        guard !isAnalyzing else { 
            print("[ProjectMode] Analysis already in progress")
            return 
        }
        guard unanalyzedCount > 0 else { 
            print("[ProjectMode] No unanalyzed inputs")
            return 
        }
        
        isAnalyzing = true
        analysisError = nil
        print("[ProjectMode] 🚀 Starting manual AI analysis...")
        
        Task {
            do {
                let cognitionService = ProjectCognitionService.shared
                
                // Get unanalyzed inputs
                let unanalyzedInputs = rawInputs.filter { !$0.input.isAnalyzed }
                print("[ProjectMode] Found \(unanalyzedInputs.count) unanalyzed inputs")
                
                let newInputs: [(source: String?, content: String)] = unanalyzedInputs.compactMap { tuple in
                    guard let item = tuple.item else { 
                        print("[ProjectMode] ⚠️ Skipping input \(tuple.input.id) - no associated item")
                        return nil 
                    }
                    print("[ProjectMode] 📄 Input content length: \(item.content.count)")
                    return (tuple.input.sourceContext, item.content)
                }
                
                print("[ProjectMode] Prepared \(newInputs.count) inputs for analysis")
                
                guard !newInputs.isEmpty else {
                    print("[ProjectMode] ❌ No valid inputs to analyze")
                    await MainActor.run {
                        self.isAnalyzing = false
                        self.analysisError = "No content to analyze".localized()
                    }
                    return
                }

                let content: String
                let changeDescription: String

                if let existingCognition = self.cognition {
                    print("[ProjectMode] 🔄 Updating existing cognition...")
                    let (updatedContent, changeDesc) = try await cognitionService.updateCognition(
                        currentCognition: existingCognition.content,
                        projectName: project.name,
                        newInputs: newInputs
                    )

                    content = updatedContent
                    changeDescription = changeDesc
                } else {
                    print("[ProjectMode] 🆕 Generating initial cognition...")
                    content = try await cognitionService.generateInitialCognition(
                        projectName: project.name,
                        projectDescription: project.description,
                        initialInputs: newInputs
                    )
                    changeDescription = "Initial cognition document generation".localized()
                }

                print("[ProjectMode] 💾 Saving cognition...")
                let addedInputIds = unanalyzedInputs.map { $0.input.id }
                let savedCognition = try projectService.saveCognition(
                    projectId: project.id,
                    content: content,
                    addedInputIds: addedInputIds,
                    changeDescription: changeDescription
                )
                print("[ProjectMode] ✅ Cognition saved: \(savedCognition.id)")
                
                // Refresh data
                await MainActor.run {
                    self.isAnalyzing = false
                    print("[ProjectMode] 🔄 Refreshing data...")
                    self.loadData()
                    print("[ProjectMode] ✨ Analysis complete!")
                    if !FloatingWindowManager.shared.isWindowVisible {
                        self.sendNotification(projectName: project.name)
                    }
                }
                
            } catch {
                print("[ProjectMode] ❌ Analysis failed: \(error)")
                await MainActor.run {
                    self.isAnalyzing = false
                    self.analysisError = self.formatErrorMessage(error)
                }
            }
        }
    }

    private func performResetAnalysis() {
        guard !isResettingAnalysis else {
            print("[ProjectMode] Reset analysis already in progress")
            return
        }
        guard cognition != nil else {
            print("[ProjectMode] No existing cognition to reset")
            return
        }
        guard !rawInputs.isEmpty else {
            print("[ProjectMode] No inputs to analyze")
            return
        }

        isResettingAnalysis = true
        analysisError = nil
        print("[ProjectMode] 🚀 Starting reset analysis...")

        Task {
            do {
                try projectService.resetAnalysisState(projectId: project.id)
                print("[ProjectMode] ✅ Reset analysis state, now triggering analysis...")

                let cognitionService = ProjectCognitionService.shared

                let allInputs: [(source: String?, content: String)] = rawInputs.compactMap { tuple in
                    guard let item = tuple.item else {
                        print("[ProjectMode] ⚠️ Skipping input \(tuple.input.id) - no associated item")
                        return nil
                    }
                    return (tuple.input.sourceContext, item.content)
                }

                guard !allInputs.isEmpty else {
                    await MainActor.run {
                        self.isResettingAnalysis = false
                        self.analysisError = "No content to analyze".localized()
                    }
                    return
                }

                print("[ProjectMode] 🆕 Regenerating cognition with \(allInputs.count) inputs...")
                let content = try await cognitionService.generateInitialCognition(
                    projectName: project.name,
                    projectDescription: project.description,
                    initialInputs: allInputs
                )

                let inputIds = rawInputs.map { $0.input.id }
                let savedCognition = try projectService.saveCognition(
                    projectId: project.id,
                    content: content,
                    addedInputIds: inputIds,
                    changeDescription: "Re-analysis - Generate new cognition based on all materials".localized()
                )

                print("[ProjectMode] ✅ Reset cognition saved: \(savedCognition.id)")

                await MainActor.run {
                    self.isResettingAnalysis = false
                    self.loadData()
                    print("[ProjectMode] ✨ Reset analysis complete!")
                    if !FloatingWindowManager.shared.isWindowVisible {
                        self.sendNotification(projectName: project.name)
                    }
                }

            } catch {
                print("[ProjectMode] ❌ Reset analysis failed: \(error)")
                await MainActor.run {
                    self.isResettingAnalysis = false
                    self.analysisError = self.formatErrorMessage(error)
                }
            }
        }
    }
}

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
            
            // Status & Actions
            HStack(spacing: 8) {
                // Incremental Analysis Button
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

                // Regenerate Button
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

                // Resetting Indicator
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
                
                // Status Indicator
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
                    Text("Analysis Failed".localized())
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
                
                // Actions
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
                // Edit Mode
                VStack(alignment: .leading, spacing: 6) {
                    // Source Context Field
                    HStack {
                        Text("Source:".localized())
                            .font(.caption)
                            .foregroundStyle(ThemeManager.shared.textSecondary)
                        TextField("Source Context Placeholder".localized(), text: $editedSourceContext)
                            .font(.caption)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    // Content Editor
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
                    
                    // Action Buttons
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
                // View Mode
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
                // AI not configured
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
                // Error state
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
                // Analyzing
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
                // Have inputs but no cognition yet - Show manual analyze button
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
                // Initial state
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
            // Header
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
            
            // Options
            Toggle("Include Raw Materials".localized(), isOn: $includeRawInputs)
                .font(.system(size: 13))
                .onChange(of: includeRawInputs) { _ in
                    generateExport()
                }
            
            Divider()
            
            // Preview
            if !exportContent.isEmpty {
                TextEditor(text: .constant(exportContent))
                    .font(.system(size: 11, design: .monospaced))
                    .frame(height: 300)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(ThemeManager.shared.borderSubtle, lineWidth: 1)
                    )
            }
            
            // Buttons
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
