import SwiftUI

struct ProjectPromptSettingsView: View {
    @ObservedObject var projectService = ProjectService.shared
    @Binding var project: Project
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTemplate: String = "默认模板"
    @State private var customPromptText: String = ""
    @State private var isEditing: Bool = false
    @State private var showResetConfirmation: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("AI Prompt 设置")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Template Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("选择模板")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        ForEach(ProjectPromptTemplates.allTemplates, id: \.name) { template in
                            TemplateRow(
                                template: template,
                                isSelected: selectedTemplate == template.name,
                                hasCustomPrompt: project.customPrompt != nil
                            ) {
                                selectedTemplate = template.name
                                if project.customPrompt == nil {
                                    customPromptText = template.initialPrompt
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    Divider()
                        .padding(.horizontal)

                    // Custom Prompt Editor
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("自定义 Prompt")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Spacer()

                            if project.customPrompt != nil {
                                Text("已自定义")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }

                            Button(isEditing ? "取消" : "编辑") {
                                if isEditing && project.customPrompt == nil {
                                    customPromptText = ProjectPromptTemplates.template(named: selectedTemplate)?.initialPrompt ?? ""
                                }
                                isEditing.toggle()
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                            .font(.caption)
                        }

                        if isEditing {
                            TextEditor(text: $customPromptText)
                                .font(.system(size: 12, design: .monospaced))
                                .frame(minHeight: 300)
                                .scrollContentBackground(.hidden)
                                .background(Color.flexokiSurfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.flexokiBorder, lineWidth: 1)
                                )

                            HStack {
                                Text("可用变量: {{PROJECT_NAME}}, {{PROJECT_DESCRIPTION}}, {{INPUTS}}, {{NEW_INPUTS}}, {{CURRENT_COGNITION}}")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)

                                Spacer()

                                Button("重置为模板") {
                                    showResetConfirmation = true
                                }
                                .buttonStyle(.borderless)
                                .controlSize(.small)
                                .font(.caption)
                                .foregroundStyle(.orange)
                            }
                        } else if let customPrompt = project.customPrompt, !customPrompt.isEmpty {
                            Text(customPrompt)
                                .font(.system(size: 12, design: .monospaced))
                                .lineLimit(5)
                                .foregroundStyle(.secondary)
                                .padding(8)
                                .background(Color.flexokiSurfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        } else {
                            Text("使用预设模板，暂无自定义内容")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        }
                    }
                    .padding(.horizontal)

                    Divider()
                        .padding(.horizontal)

                    // Preview Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Prompt 预览")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(getCurrentPrompt())
                            .font(.system(size: 11, design: .monospaced))
                            .lineLimit(10)
                            .foregroundStyle(.tertiary)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.flexokiSurfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }

            Divider()

            // Actions
            HStack {
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                if isEditing || project.customPrompt != nil {
                    Button("清除自定义") {
                        clearCustomPrompt()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundStyle(.orange)
                }

                Button("保存") {
                    saveCustomPrompt()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!isEditing)
            }
            .padding()
        }
        .frame(width: 550, height: 650)
        .onAppear {
            loadCurrentState()
        }
        .alert("重置为模板", isPresented: $showResetConfirmation) {
            Button("取消", role: .cancel) { }
            Button("重置", role: .destructive) {
                resetToTemplate()
            }
        } message: {
            Text("确定要将自定义 Prompt 重置为所选模板吗？此操作不可撤销。")
        }
    }

    private func loadCurrentState() {
        if let customPrompt = project.customPrompt, !customPrompt.isEmpty {
            customPromptText = customPrompt
            isEditing = false
            selectedTemplate = "自定义"
        } else {
            selectedTemplate = "默认模板"
            customPromptText = ProjectPromptTemplates.defaultTemplate.initialPrompt
        }
    }

    private func getCurrentPrompt() -> String {
        if let customPrompt = project.customPrompt, !customPrompt.isEmpty, !isEditing {
            return customPrompt
        }
        if isEditing {
            return customPromptText
        }
        return ProjectPromptTemplates.template(named: selectedTemplate)?.initialPrompt ?? ""
    }

    private func saveCustomPrompt() {
        var updatedProject = project
        updatedProject.customPrompt = customPromptText.isEmpty ? nil : customPromptText
        do {
            try projectService.updateProject(updatedProject)
            project = updatedProject
            isEditing = false
        } catch {
            print("[ProjectPromptSettings] Failed to save: \(error)")
        }
    }

    private func clearCustomPrompt() {
        var updatedProject = project
        updatedProject.customPrompt = nil
        do {
            try projectService.updateProject(updatedProject)
            project = updatedProject
            loadCurrentState()
        } catch {
            print("[ProjectPromptSettings] Failed to clear: \(error)")
        }
    }

    private func resetToTemplate() {
        if let template = ProjectPromptTemplates.template(named: selectedTemplate) {
            customPromptText = template.initialPrompt
        }
    }
}

struct TemplateRow: View {
    let template: ProjectPromptTemplate
    let isSelected: Bool
    let hasCustomPrompt: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(template.name)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if hasCustomPrompt {
                            Image(systemName: "sparkle")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }

                    Text(template.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

struct ProjectPromptSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ProjectPromptSettingsView(project: .constant(
            Project(name: "测试项目", description: "测试描述")
        ))
    }
}
