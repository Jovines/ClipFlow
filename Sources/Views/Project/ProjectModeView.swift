// swiftlint:disable file_length
import SwiftUI
import AppKit
import MarkdownView
import UserNotifications

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
}

extension ProjectModeView {
    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in
                loadData()
            }
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
            analysisError = "Failed to load project data: %1$@".localized(error.localizedDescription)
        }
    }
    
    private func deleteRawInput(id: UUID) {
        do {
            try projectService.deleteRawInput(id: id)
            print("[ProjectMode] ✅ Deleted raw input: \(id)")
            loadData()
        } catch {
            print("[ProjectMode] ❌ Failed to delete raw input: \(error)")
            analysisError = "Failed to delete material: %1$@".localized(error.localizedDescription)
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
            analysisError = "Failed to update material: %1$@".localized(error.localizedDescription)
        }
    }
    
    @MainActor
    private func sendNotification(projectName: String) {
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()

            if settings.authorizationStatus == .notDetermined {
                let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
                guard granted else { return }
                await deliverProjectAnalysisNotification(projectName: projectName)
                return
            }

            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                return
            }

            await deliverProjectAnalysisNotification(projectName: projectName)
        }
    }

    private func deliverProjectAnalysisNotification(projectName: String) async {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "AI Analysis Complete".localized()
        content.body = "AI analysis for project \"%1$@\" is complete".localized(projectName)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "project-analysis-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        try? await center.add(request)
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
            analysisError = "Analysis is already in progress".localized()
            return 
        }
        guard unanalyzedCount > 0 else { 
            print("[ProjectMode] No unanalyzed inputs")
            analysisError = "No new materials to analyze".localized()
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
            analysisError = "Analysis is already in progress".localized()
            return
        }
        guard cognition != nil else {
            print("[ProjectMode] No existing cognition to reset")
            analysisError = "No existing analysis result to reset".localized()
            return
        }
        guard !rawInputs.isEmpty else {
            print("[ProjectMode] No inputs to analyze")
            analysisError = "No materials to analyze".localized()
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
