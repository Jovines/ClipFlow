import SwiftUI

struct ProjectPromptSettingsView: View {
    @ObservedObject var projectService = ProjectService.shared
    @ObservedObject var templateService = PromptTemplateService.shared
    @Binding var project: Project
    @Environment(\.dismiss) private var dismiss

    var onApply: (() -> Void)?

    @State private var selectedTemplateId: UUID?
    @State private var templates: [PromptTemplate] = []
    @State private var showCreateTemplate = false
    @State private var editingTemplate: PromptTemplate?
    @State private var showDeleteConfirmation = false
    @State private var templateToDelete: PromptTemplate?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("AI Prompt 模板设置")
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

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("选择模板")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                    Divider()

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(templates) { template in
                                TemplateRow(
                                    template: template,
                                    isSelected: selectedTemplateId == template.id,
                                    isSystem: template.isSystem
                                ) {
                                    selectTemplate(template.id)
                                }
                                .contextMenu {
                                    if !template.isSystem {
                                        Button("编辑") {
                                            editingTemplate = template
                                        }
                                        Button("复制模板") {
                                            duplicateTemplate(template)
                                        }
                                        Divider()
                                        Button("删除", role: .destructive) {
                                            templateToDelete = template
                                            showDeleteConfirmation = true
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .frame(width: 200)
                .background(Color.flexokiSurface)

                Rectangle()
                    .fill(Color.flexokiBorder)
                    .frame(width: 1)

                VStack(alignment: .leading, spacing: 12) {
                    if let template = getSelectedTemplate() {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(template.name)
                                    .font(.headline)

                                if template.isSystem {
                                    Text("预设")
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.1))
                                        .foregroundStyle(Color.accentColor)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                } else {
                                    Text("自定义")
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.1))
                                        .foregroundStyle(.green)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }

                                Spacer()

                                if !template.isSystem {
                                    Button("编辑") {
                                        editingTemplate = template
                                    }
                                    .buttonStyle(.borderless)
                                    .controlSize(.small)
                                }
                            }

                            if !template.description.isEmpty {
                                Text(template.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()

                        Divider()

                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("初始生成 Prompt")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.secondary)

                                    TextEditor(text: .constant(template.initialPrompt))
                                        .font(.system(size: 11, design: .monospaced))
                                        .frame(height: 150)
                                        .scrollContentBackground(.hidden)
                                        .background(Color.flexokiSurfaceElevated)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(Color.flexokiBorder, lineWidth: 1)
                                        )
                                        .disabled(true)
                                }
                                .padding(.horizontal)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("更新认知 Prompt")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.secondary)

                                    TextEditor(text: .constant(template.updatePrompt))
                                        .font(.system(size: 11, design: .monospaced))
                                        .frame(height: 150)
                                        .scrollContentBackground(.hidden)
                                        .background(Color.flexokiSurfaceElevated)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(Color.flexokiBorder, lineWidth: 1)
                                        )
                                        .disabled(true)
                                }
                                .padding(.horizontal)

                                HStack {
                                    Text("可用变量: {{PROJECT_NAME}}, {{PROJECT_DESCRIPTION}}, {{INPUTS}}, {{NEW_INPUTS}}, {{CURRENT_COGNITION}}")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal)
                            }
                            .padding(.vertical)
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 40))
                                .foregroundStyle(.tertiary)

                            Text("选择一个模板")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .background(Color.flexokiBackground)
            }

            Divider()

            HStack {
                Button("创建新模板") {
                    showCreateTemplate = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("应用此模板") {
                    applyTemplate()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(selectedTemplateId == nil)
            }
            .padding()
        }
        .frame(width: 750, height: 550)
        .onAppear {
            loadTemplates()
            selectedTemplateId = project.selectedPromptTemplateId ?? SystemPromptTemplates.default.id
        }
        .sheet(isPresented: $showCreateTemplate) {
            TemplateEditSheet(template: nil) { newTemplate in
                try? templateService.createTemplate(
                    name: newTemplate.name,
                    description: newTemplate.description,
                    initialPrompt: newTemplate.initialPrompt,
                    updatePrompt: newTemplate.updatePrompt
                )
                loadTemplates()
            }
        }
        .sheet(item: $editingTemplate) { template in
            TemplateEditSheet(template: template) { updatedTemplate in
                try? templateService.updateTemplate(updatedTemplate)
                loadTemplates()
            }
        }
        .alert("删除模板", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                if let template = templateToDelete {
                    try? templateService.deleteTemplate(id: template.id)
                    if selectedTemplateId == template.id {
                        selectedTemplateId = SystemPromptTemplates.default.id
                    }
                    loadTemplates()
                }
            }
        } message: {
            if let template = templateToDelete {
                Text("确定要删除模板「\(template.name)」吗？此操作不可撤销，使用该模板的项目将恢复使用默认模板。")
            }
        }
    }

    private func loadTemplates() {
        do {
            var allTemplates = try templateService.fetchAllTemplates()
            let systemIds = Set(SystemPromptTemplates.all.map { $0.id })
            let customTemplates = allTemplates.filter { !systemIds.contains($0.id) }
            let systemTemplates = SystemPromptTemplates.all
            templates = systemTemplates + customTemplates
        } catch {
            print("[ProjectPromptSettings] Failed to load templates: \(error)")
            templates = SystemPromptTemplates.all
        }
    }

    private func getSelectedTemplate() -> PromptTemplate? {
        guard let id = selectedTemplateId else { return nil }
        if let systemTemplate = SystemPromptTemplates.template(for: id) {
            return systemTemplate
        }
        return templates.first { $0.id == id }
    }

    private func selectTemplate(_ id: UUID) {
        selectedTemplateId = id
    }

    private func applyTemplate() {
        guard let templateId = selectedTemplateId else { return }
        var updatedProject = project
        updatedProject.selectedPromptTemplateId = templateId
        do {
            try projectService.updateProject(updatedProject)
            project = updatedProject
            dismiss()
            onApply?()
        } catch {
            print("[ProjectPromptSettings] Failed to apply template: \(error)")
        }
    }

    private func duplicateTemplate(_ template: PromptTemplate) {
        do {
            let newTemplate = try templateService.duplicateTemplate(template)
            loadTemplates()
            selectedTemplateId = newTemplate.id
        } catch {
            print("[ProjectPromptSettings] Failed to duplicate template: \(error)")
        }
    }
}

struct TemplateRow: View {
    let template: PromptTemplate
    let isSelected: Bool
    let isSystem: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: isSystem ? "lock.fill" : "doc.text")
                    .font(.caption)
                    .foregroundStyle(isSystem ? .tertiary : .secondary)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(.primary)

                    Text(template.description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

struct TemplateEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    let template: PromptTemplate?
    let onSave: (PromptTemplate) -> Void

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var initialPrompt: String = ""
    @State private var updatePrompt: String = ""

    var isEditing: Bool {
        template != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isEditing ? "编辑模板" : "创建模板")
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
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("模板名称")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("输入模板名称", text: $name)
                                .textFieldStyle(.roundedBorder)
                                .controlSize(.small)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("描述")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("简短描述用途", text: $description)
                                .textFieldStyle(.roundedBorder)
                                .controlSize(.small)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("初始生成 Prompt")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $initialPrompt)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(height: 200)
                            .scrollContentBackground(.hidden)
                            .background(Color.flexokiSurfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.flexokiBorder, lineWidth: 1)
                            )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("更新认知 Prompt")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $updatePrompt)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(height: 200)
                            .scrollContentBackground(.hidden)
                            .background(Color.flexokiSurfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.flexokiBorder, lineWidth: 1)
                            )
                    }

                    Text("可用变量: {{PROJECT_NAME}}, {{PROJECT_DESCRIPTION}}, {{INPUTS}}, {{NEW_INPUTS}}, {{CURRENT_COGNITION}}")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding()
            }

            Divider()

            HStack {
                Spacer()
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("保存") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(name.isEmpty || initialPrompt.isEmpty || updatePrompt.isEmpty)
            }
            .padding()
        }
        .frame(width: 600, height: 650)
        .onAppear {
            if let template = template {
                name = template.name
                description = template.description
                initialPrompt = template.initialPrompt
                updatePrompt = template.updatePrompt
            } else {
                initialPrompt = SystemPromptTemplates.default.initialPrompt
                updatePrompt = SystemPromptTemplates.default.updatePrompt
            }
        }
    }

    private func save() {
        let savedTemplate = PromptTemplate(
            id: template?.id ?? UUID(),
            name: name,
            description: description,
            initialPrompt: initialPrompt,
            updatePrompt: updatePrompt,
            isSystem: false,
            createdAt: template?.createdAt ?? Date(),
            updatedAt: Date()
        )
        onSave(savedTemplate)
        dismiss()
    }
}

struct ProjectPromptSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ProjectPromptSettingsView(project: .constant(
            Project(name: "测试项目", description: "测试描述")
        ))
    }
}
