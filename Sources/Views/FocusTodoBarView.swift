import AppKit
import SwiftUI

struct FocusTodoBarView: View {
    private let cornerRadius: CGFloat = 12

    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var todoService = FocusTodoService.shared
    @StateObject private var clipboardMonitor = ClipboardMonitor.shared
    @StateObject private var shortcutManager = FocusTodoShortcutManager.shared
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var aiService = OpenAIService.shared
    @AppStorage(FocusTodoPreferences.clipboardPrefillSecondsKey) private var clipboardPrefillSeconds = FocusTodoPreferences.defaultClipboardPrefillSeconds
    @AppStorage(FocusTodoPreferences.collapsedOpacityKey) private var collapsedOpacity = FocusTodoPreferences.defaultCollapsedOpacity
    @State private var newTaskTitle = ""
    @State private var rewriteCandidates: [String] = []
    @State private var rewriteErrorMessage: String?
    @State private var isRewritingTask = false
    @State private var rewriteTask: Task<Void, Never>?
    @State private var activeTitleTransitionSerial = 0
    @State private var collapsedInteractionBoost = 0.0
    @State private var switchColorPulse = 0.0
    @State private var collapsedOpacityWorkItem: DispatchWorkItem?
    @State private var switchPulseWorkItem: DispatchWorkItem?
    @FocusState private var isQuickInputFocused: Bool

    private struct DoneGroup: Identifiable {
        let date: Date
        let items: [FocusTodoItem]
        var id: Date { date }
    }

    private var pastDoneGroups: [DoneGroup] {
        let calendar = Calendar.current
        let pastDoneItems = todoService.items.filter { item in
            guard item.state == .done, let completedAt = item.completedAt else { return false }
            return !calendar.isDateInToday(completedAt)
        }

        let grouped = Dictionary(grouping: pastDoneItems) { item in
            calendar.startOfDay(for: item.completedAt ?? .distantPast)
        }

        return grouped
            .map { date, items in
                let sortedItems = items.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
                return DoneGroup(date: date, items: sortedItems)
            }
            .sorted { $0.date > $1.date }
    }

    private var collapsedPendingRing: [FocusTodoItem] {
        todoService.items.filter { $0.state == .pending }
    }

    private var collapsedPendingCount: Int {
        collapsedPendingRing.count
    }

    private var hasCollapsedActiveTask: Bool {
        todoService.activeItem != nil
    }

    private var togglePanelShortcutDisplay: String {
        shortcutManager.shortcut(for: .togglePanel).displayString
    }

    private var collapsedPreviousTaskTitle: String? {
        guard let activeId = todoService.activeItemId,
              let currentIndex = collapsedPendingRing.firstIndex(where: { $0.id == activeId }),
              collapsedPendingRing.count > 1 else {
            return nil
        }

        let previousIndex = (currentIndex - 1 + collapsedPendingRing.count) % collapsedPendingRing.count
        return collapsedPendingRing[previousIndex].title
    }

    private var collapsedNextTaskTitle: String? {
        guard let activeId = todoService.activeItemId,
              let currentIndex = collapsedPendingRing.firstIndex(where: { $0.id == activeId }),
              collapsedPendingRing.count > 1 else {
            return nil
        }

        let nextIndex = (currentIndex + 1) % collapsedPendingRing.count
        return collapsedPendingRing[nextIndex].title
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            if todoService.isPanelExpanded {
                Divider()
                    .background(themeManager.separator)

                expandedPanel
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(todoService.isPanelExpanded ? 4 : 2)
        .background(backgroundView)
        .mask(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(themeManager.separator.opacity(todoService.isPanelExpanded ? 0.82 : collapsedStrokeOpacity), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(themeManager.accent.opacity(switchColorPulse))
        )
        .shadow(
            color: .black.opacity(todoService.isPanelExpanded ? 0.08 : 0.02),
            radius: todoService.isPanelExpanded ? 8 : 3,
            y: todoService.isPanelExpanded ? 4 : 1
        )
        .themeAware()
        .environment(\.locale, languageManager.currentLanguage.locale)
        .id(languageManager.refreshTrigger)
        .compositingGroup()
        .onChange(of: todoService.isPanelExpanded) { _, _ in
            FocusTodoWindowManager.shared.refreshLayout()
            if todoService.isPanelExpanded {
                prefillFromRecentClipboardIfNeeded()
                DispatchQueue.main.async {
                    isQuickInputFocused = true
                }
            } else {
                isQuickInputFocused = false
                clearRewriteState(cancelInFlight: true)
            }
        }
        .onChange(of: todoService.activeSwitchSerial) { _, _ in
            withAnimation(.spring(duration: 0.24, bounce: 0.18)) {
                activeTitleTransitionSerial += 1
            }
            triggerSwitchBackgroundFeedback()
        }
        .onChange(of: todoService.collapsedInteractionSerial) { _, _ in
            triggerCollapsedInteractionFeedback()
        }
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: FocusTodoBarHeightPreferenceKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(FocusTodoBarHeightPreferenceKey.self) { height in
            todoService.updateMeasuredHeight(height, expanded: todoService.isPanelExpanded)
            FocusTodoWindowManager.shared.refreshLayout(animated: false)
        }
        .onChange(of: todoService.activeItemId) { _, _ in
            if !todoService.isPanelExpanded {
                FocusTodoWindowManager.shared.refreshLayout()
            }
        }
    }

    private var headerBar: some View {
        let isExpanded = todoService.isPanelExpanded

        return HStack(spacing: isExpanded ? 6 : 4) {
            Image(systemName: "target")
                .font(.system(size: isExpanded ? 10 : 8, weight: .semibold))
                .foregroundStyle(themeManager.iconAccent)
                .frame(width: isExpanded ? 18 : 12, height: isExpanded ? 18 : 12)
                .background(themeManager.iconBadgeAccentBackground.opacity(isExpanded ? 1.0 : 0.36))
                .clipShape(Circle())

            if isExpanded {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Now".localized)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(themeManager.textSecondary)

                    animatedActiveTitleText()
                }
            } else {
                if hasCollapsedActiveTask {
                    VStack(alignment: .leading, spacing: -1) {
                        Text(collapsedPreviousTaskTitle.map { "↑ %@".localized($0) } ?? "")
                            .font(.system(size: 6.5, weight: .regular))
                            .lineLimit(1)
                            .foregroundStyle(themeManager.textTertiary)
                            .shadow(color: .black.opacity(0.28), radius: 1.2, y: 0.6)
                            .opacity(collapsedPreviousTaskTitle == nil ? 0 : 1)

                        animatedActiveTitleText(fontSize: 10.5)

                        Text(collapsedNextTaskTitle.map { "↓ %@".localized($0) } ?? "")
                            .font(.system(size: 6.5, weight: .regular))
                            .lineLimit(1)
                            .foregroundStyle(themeManager.textTertiary)
                            .shadow(color: .black.opacity(0.28), radius: 1.2, y: 0.6)
                            .opacity(collapsedNextTaskTitle == nil ? 0 : 1)
                    }
                } else {
                    Text("No task".localized)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(themeManager.textSecondary)
                        .shadow(color: .black.opacity(0.18), radius: 1.0, y: 0.5)
                }
            }

            Spacer()

            if isExpanded, let next = todoService.queuedItems.first {
                Text("Next: %@".localized(next.title))
                    .font(.system(size: 10))
                    .foregroundStyle(themeManager.textSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: 120, alignment: .trailing)
            } else {
                VStack(alignment: .trailing, spacing: 1) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.badge.checkmark")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(themeManager.textTertiary)

                        Text("\(collapsedPendingCount)")
                            .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(themeManager.textSecondary)
                            .monospacedDigit()
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(themeManager.chromeSurfaceElevated.opacity(0.65))
                            )
                    }
                    .shadow(color: .black.opacity(0.18), radius: 1.0, y: 0.5)

                    HStack(spacing: 4) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 7.5, weight: .medium))
                        Text(togglePanelShortcutDisplay)
                            .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(themeManager.textSecondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(themeManager.chromeSurfaceElevated.opacity(0.78))
                    )
                }
            }

            if isExpanded {
                actionIcon(systemName: "checkmark", color: themeManager.iconBadgeAccentForeground, background: themeManager.iconBadgeAccentBackground) {
                    todoService.markCurrentDone()
                }

                actionIcon(systemName: "forward.fill", color: themeManager.iconBadgeAccentForeground, background: themeManager.iconBadgeAccentBackground) {
                    todoService.moveToNext()
                }

                actionIcon(systemName: "chevron.up", color: themeManager.textSecondary, background: themeManager.chromeSurfaceElevated) {
                    todoService.togglePanel()
                }
            }
        }
        .padding(.horizontal, isExpanded ? 8 : 6)
        .padding(.vertical, isExpanded ? 4 : 1)
        .contentShape(Rectangle())
    }

    private var expandedPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            quickInputRow

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    todoSection(title: "Now".localized, items: todoService.activeItem.map { [$0] } ?? [], accent: true)
                    todoSection(title: "Next Up".localized, items: todoService.queuedItems, accent: false)
                    todoSection(title: "Paused".localized, items: todoService.pausedItems, accent: false, paused: true)
                    todoSection(title: "Done Today".localized, items: todoService.doneTodayItems, accent: false, done: true)
                    doneHistorySection
                }
                .padding(.bottom, 6)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var doneHistorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Done History".localized)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(themeManager.textSecondary)
                Spacer()
                Text("\(pastDoneGroups.reduce(0) { $0 + $1.items.count })")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(themeManager.textTertiary)
            }

            if pastDoneGroups.isEmpty {
                Text("Empty".localized)
                    .font(.system(size: 11))
                    .foregroundStyle(themeManager.textTertiary)
                    .padding(.vertical, 2)
            } else {
                ForEach(pastDoneGroups) { group in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dateLabel(for: group.date))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(themeManager.textSecondary)

                        ForEach(group.items) { item in
                            todoRow(item: item, accent: false, paused: false, done: true)
                        }
                    }
                }
            }
        }
    }

    private var quickInputRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField("Quick add task".localized, text: $newTaskTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(themeManager.chromeSurfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .focused($isQuickInputFocused)
                    .onSubmit {
                        addCurrentTask()
                    }

                Button {
                    requestTaskRewrites()
                } label: {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(themeManager.text)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(themeManager.chromeSurfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isRewritingTask || !canTriggerRewrite)
                .help(rewriteButtonHelpText)

                Button("Add".localized) {
                    addCurrentTask()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(themeManager.iconBadgeAccentForeground)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(themeManager.iconBadgeAccentBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if isRewritingTask {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.55)
                    Text("Generating rewrite suggestions...".localized)
                        .font(.system(size: 11))
                        .foregroundStyle(themeManager.textSecondary)
                }
            }

            if let rewriteErrorMessage, !rewriteErrorMessage.isEmpty {
                Text(rewriteErrorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.red.opacity(0.85))
            }

            if !rewriteCandidates.isEmpty {
                Text("Select a rewrite candidate:".localized)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(themeManager.textSecondary)

                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(rewriteCandidates.enumerated()), id: \.offset) { index, candidate in
                        Button {
                            newTaskTitle = candidate
                            rewriteErrorMessage = nil
                            DispatchQueue.main.async {
                                isQuickInputFocused = true
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 6) {
                                Text("\(index + 1).")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(themeManager.textSecondary)

                                Text(candidate)
                                    .font(.system(size: 11))
                                    .foregroundStyle(themeManager.text)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(themeManager.chromeSurfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var canTriggerRewrite: Bool {
        !newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && aiService.hasAnyConfiguredProvider
    }

    private var rewriteButtonHelpText: String {
        if aiService.hasAnyConfiguredProvider {
            return "Rewrite input into actionable task options".localized
        }
        return "Configure AI provider in settings to use rewrite".localized
    }

    private func addCurrentTask() {
        todoService.addTask(newTaskTitle, makeActive: false)
        newTaskTitle = ""
        clearRewriteState(cancelInFlight: true)
    }

    private func requestTaskRewrites() {
        let sourceText = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sourceText.isEmpty else { return }
        guard aiService.hasAnyConfiguredProvider else {
            rewriteErrorMessage = "AI is not configured. Please set up a provider in Settings > AI Service.".localized
            return
        }

        isRewritingTask = true
        rewriteErrorMessage = nil
        rewriteCandidates = []
        rewriteTask?.cancel()

        rewriteTask = Task {
            do {
                let candidates = try await FocusTodoAIRewriteService.shared.generateCandidates(from: sourceText)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    isRewritingTask = false
                    rewriteCandidates = candidates
                    if candidates.isEmpty {
                        rewriteErrorMessage = "No rewrite suggestions generated. Try adding more context.".localized
                    }
                    rewriteTask = nil
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    isRewritingTask = false
                    rewriteCandidates = []
                    rewriteErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    rewriteTask = nil
                }
            }
        }
    }

    private func clearRewriteState(cancelInFlight: Bool) {
        if cancelInFlight {
            rewriteTask?.cancel()
            rewriteTask = nil
        }
        isRewritingTask = false
        rewriteCandidates = []
        rewriteErrorMessage = nil
    }

    private func todoSection(
        title: String,
        items: [FocusTodoItem],
        accent: Bool,
        paused: Bool = false,
        done: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(themeManager.textSecondary)
                Spacer()
                Text("\(items.count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(themeManager.textTertiary)
            }

            if items.isEmpty {
                Text("Empty".localized)
                    .font(.system(size: 11))
                    .foregroundStyle(themeManager.textTertiary)
                    .padding(.vertical, 2)
            } else {
                ForEach(items) { item in
                    todoRow(item: item, accent: accent, paused: paused, done: done)
                }
            }
        }
    }

    private func todoRow(item: FocusTodoItem, accent: Bool, paused: Bool, done: Bool) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(accent ? themeManager.accent : themeManager.textSecondary.opacity(0.5))
                .frame(width: 6, height: 6)

            Text(item.title)
                .font(.system(size: 12, weight: accent ? .medium : .regular))
                .lineLimit(1)
                .foregroundStyle(done ? themeManager.textTertiary : themeManager.text)
                .strikethrough(done)

            Spacer()

            if paused {
                rowButton("play.fill") {
                    todoService.resumePaused(item.id)
                }
            } else if done {
                rowButton("arrow.uturn.backward") {
                    todoService.restoreDone(item.id, makeActive: false)
                }
            } else if !done {
                rowButton("target") {
                    todoService.setActive(item.id)
                }

                rowButton("pause.fill") {
                    todoService.setActive(item.id)
                    todoService.pauseCurrent()
                }

                rowButton("checkmark") {
                    if todoService.activeItem?.id != item.id {
                        todoService.setActive(item.id)
                    }
                    todoService.markCurrentDone()
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(accent ? themeManager.activeBackground : themeManager.chromeSurface.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            guard !done else { return }
            todoService.setActive(item.id)
        }
    }

    private var backgroundView: some View {
        Group {
            if themeManager.isLiquidGlassEnabled {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(todoService.isPanelExpanded ? 0.88 : effectiveCollapsedOpacity)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(themeManager.surface.opacity(todoService.isPanelExpanded ? 0.90 : max(0.03, effectiveCollapsedOpacity - 0.08)))
            }
        }
    }

    private func actionIcon(systemName: String, color: Color, background: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 20, height: 20)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func dateLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = languageManager.currentLanguage.locale
        return formatter.string(from: date)
    }

    private func rowButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(themeManager.iconBadgeAccentForeground)
                .frame(width: 18, height: 18)
                .background(themeManager.iconBadgeAccentBackground)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func animatedActiveTitleText(fontSize: CGFloat = 11) -> some View {
        ZStack {
            Text(todoService.activeItem?.title ?? "No task in progress".localized)
                .id(activeTitleTransitionSerial)
                .font(.system(size: fontSize, weight: .medium))
                .lineLimit(1)
                .foregroundStyle(themeManager.text)
                .shadow(color: .black.opacity(todoService.isPanelExpanded ? 0.06 : 0.24), radius: 1.2, y: 0.6)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
        }
        .animation(.spring(duration: 0.24, bounce: 0.18), value: activeTitleTransitionSerial)
    }

    private func prefillFromRecentClipboardIfNeeded() {
        guard clipboardPrefillSeconds > 0 else { return }
        guard let recentTextItem = clipboardMonitor.capturedItems.first(where: { $0.contentType.rawValue == "text" }) else { return }

        let elapsed = Date().timeIntervalSince(recentTextItem.createdAt)
        guard elapsed <= clipboardPrefillSeconds else { return }

        newTaskTitle = recentTextItem.content
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
        }
    }

    private var effectiveCollapsedOpacity: Double {
        min(0.9, max(0.05, collapsedOpacity + collapsedInteractionBoost))
    }

    private var collapsedStrokeOpacity: Double {
        min(0.55, max(0.18, 0.16 + effectiveCollapsedOpacity * 0.26))
    }

    private func triggerCollapsedInteractionFeedback() {
        guard !todoService.isPanelExpanded else { return }

        collapsedOpacityWorkItem?.cancel()

        withAnimation(.easeOut(duration: 0.12)) {
            collapsedInteractionBoost = 0.24
        }

        let workItem = DispatchWorkItem {
            withAnimation(.easeOut(duration: 1.0)) {
                collapsedInteractionBoost = 0
            }
        }
        collapsedOpacityWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }

    private func triggerSwitchBackgroundFeedback() {
        switchPulseWorkItem?.cancel()

        withAnimation(.easeOut(duration: 0.12)) {
            switchColorPulse = todoService.isPanelExpanded ? 0.12 : 0.08
        }

        let workItem = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.32)) {
                switchColorPulse = 0
            }
        }
        switchPulseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06, execute: workItem)

        if !todoService.isPanelExpanded {
            triggerCollapsedInteractionFeedback()
        }
    }
}

private struct FocusTodoBarHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview {
    FocusTodoBarView()
        .frame(width: 620, height: 300)
}
