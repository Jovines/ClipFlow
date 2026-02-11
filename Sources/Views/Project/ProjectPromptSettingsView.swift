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
                Text("AI Prompt Template Settings".localized)
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
                    Text("Select Template".localized)
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
                                        Button("Edit".localized) {
                                            editingTemplate = template
                                        }
                                        Button("Copy Template".localized) {
                                            duplicateTemplate(template)
                                        }
                                        Divider()
                                        Button("Delete".localized, role: .destructive) {
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
                .background(ThemeManager.shared.surface)

                Rectangle()
                    .fill(ThemeManager.shared.border)
                    .frame(width: 1)

                VStack(alignment: .leading, spacing: 12) {
                    if let template = getSelectedTemplate() {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(template.name)
                                    .font(.headline)

                                if template.isSystem {
                                    Text("Preset".localized)
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.flexokiAccent.opacity(0.1))
                                        .foregroundStyle(Color.flexokiAccent)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                } else {
                                    Text("Custom".localized)
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.flexokiGreen600.opacity(0.1))
                                        .foregroundStyle(Color.flexokiGreen600)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }

                                Spacer()

                                if !template.isSystem {
                                    Button("Edit".localized) {
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
                                    Text("Initial Generation Prompt".localized)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.secondary)

                                    TextEditor(text: .constant(template.initialPrompt))
                                        .font(.system(size: 11, design: .monospaced))
                                        .frame(height: 150)
                                        .scrollContentBackground(.hidden)
                                        .background(ThemeManager.shared.surfaceElevated)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(ThemeManager.shared.border, lineWidth: 1)
                                        )
                                        .disabled(true)
                                }
                                .padding(.horizontal)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Update Cognition Prompt".localized)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.secondary)

                                    TextEditor(text: .constant(template.updatePrompt))
                                        .font(.system(size: 11, design: .monospaced))
                                        .frame(height: 150)
                                        .scrollContentBackground(.hidden)
                                        .background(ThemeManager.shared.surfaceElevated)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(ThemeManager.shared.border, lineWidth: 1)
                                        )
                                        .disabled(true)
                                }
                                .padding(.horizontal)

                                HStack {
                                    Text("Available Variables: {{PROJECT_NAME}}, {{PROJECT_DESCRIPTION}}, {{INPUTS}}, {{NEW_INPUTS}}, {{CURRENT_COGNITION}}".localized)
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

                            Text("Select a Template".localized)
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
                Button("Create New Template".localized) {
                    showCreateTemplate = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button("Cancel".localized) {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Apply Template".localized) {
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
        .alert("Delete Template".localized, isPresented: $showDeleteConfirmation) {
            Button("Cancel".localized, role: .cancel) { }
            Button("Delete".localized, role: .destructive) {
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
                Text("Delete Template Warning".localized(template.name))
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
                        .foregroundStyle(Color.flexokiAccent)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.flexokiAccent.opacity(0.1) : Color.clear)
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
                Text(isEditing ? "Edit Template".localized : "Create Template".localized)
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
                            Text("Template Name".localized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Enter Template Name".localized, text: $name)
                                .textFieldStyle(.roundedBorder)
                                .controlSize(.small)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description".localized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Brief Description".localized, text: $description)
                                .textFieldStyle(.roundedBorder)
                                .controlSize(.small)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Initial Generation Prompt".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $initialPrompt)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(height: 200)
                            .scrollContentBackground(.hidden)
                            .background(ThemeManager.shared.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(ThemeManager.shared.border, lineWidth: 1)
                            )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Update Cognition Prompt".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $updatePrompt)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(height: 200)
                            .scrollContentBackground(.hidden)
                            .background(ThemeManager.shared.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(ThemeManager.shared.border, lineWidth: 1)
                            )
                    }

                    Text("Available Variables: {{PROJECT_NAME}}, {{PROJECT_DESCRIPTION}}, {{INPUTS}}, {{NEW_INPUTS}}, {{CURRENT_COGNITION}}".localized)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding()
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancel".localized) {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Save".localized) {
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
            Project(name: "Test Project".localized, description: "Test Description".localized)
        ))
    }
}
