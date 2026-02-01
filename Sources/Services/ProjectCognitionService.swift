import Foundation
import OpenAI
import GRDB

final class ProjectCognitionService {
    static let shared = ProjectCognitionService()

    private init() {}

    func generateInitialCognition(
        projectName: String,
        projectDescription: String?,
        initialInputs: [(source: String?, content: String)],
        template: PromptTemplate? = nil
    ) async throws -> String {
        print("[ProjectCognition] Generating initial cognition for: \(projectName)")
        print("[ProjectCognition] Inputs count: \(initialInputs.count)")

        let selectedTemplate = template ?? SystemPromptTemplates.default
        let prompt = buildInitialCognitionPrompt(
            projectName: projectName,
            projectDescription: projectDescription,
            inputs: initialInputs,
            template: selectedTemplate
        )

        print("[ProjectCognition] Prompt length: \(prompt.count) characters")

        return try await generateCognition(prompt: prompt)
    }

    func updateCognition(
        currentCognition: String,
        projectName: String,
        newInputs: [(source: String?, content: String)],
        template: PromptTemplate? = nil
    ) async throws -> (updatedCognition: String, changeDescription: String) {
        print("[ProjectCognition] Updating cognition for: \(projectName)")
        print("[ProjectCognition] New inputs count: \(newInputs.count)")

        let selectedTemplate = template ?? SystemPromptTemplates.default
        let prompt = buildUpdateCognitionPrompt(
            currentCognition: currentCognition,
            projectName: projectName,
            newInputs: newInputs,
            template: selectedTemplate
        )

        print("[ProjectCognition] Update prompt length: \(prompt.count) characters")

        let content = try await generateCognition(prompt: prompt)

        let changePrompt = """
        根据以下信息变化，用一句话描述这次更新的核心变化：

        新认知文档内容开头：\(content.prefix(100))

        请用一句话描述这次更新的核心变化（如："识别出性能瓶颈问题"、"明确了缓存策略"等）：
        """

        print("[ProjectCognition] Generating change description...")
        let changeDescription = try await OpenAIService.shared.chat(message: changePrompt)

        print("[ProjectCognition] Change description: \(changeDescription)")

        return (content, changeDescription.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func generateCognition(prompt: String) async throws -> String {
        print("[ProjectCognition] Calling AI service...")

        do {
            let response = try await OpenAIService.shared.chat(message: prompt)
            print("[ProjectCognition] AI response received, length: \(response.count)")
            return response
        } catch {
            print("[ProjectCognition] ❌ AI call failed: \(error)")
            throw error
        }
    }

    private func buildInitialCognitionPrompt(
        projectName: String,
        projectDescription: String?,
        inputs: [(source: String?, content: String)],
        template: PromptTemplate
    ) -> String {
        fillPromptTemplate(
            template: template.initialPrompt,
            projectName: projectName,
            projectDescription: projectDescription,
            inputs: inputs,
            currentCognition: nil
        )
    }

    private func buildUpdateCognitionPrompt(
        currentCognition: String,
        projectName: String,
        newInputs: [(source: String?, content: String)],
        template: PromptTemplate
    ) -> String {
        fillPromptTemplate(
            template: template.updatePrompt,
            projectName: projectName,
            projectDescription: nil,
            inputs: newInputs,
            currentCognition: currentCognition
        )
    }

    private func fillPromptTemplate(
        template: String,
        projectName: String,
        projectDescription: String?,
        inputs: [(source: String?, content: String)],
        currentCognition: String?
    ) -> String {
        var result = template

        result = result.replacingOccurrences(of: "{{PROJECT_NAME}}", with: projectName)

        if let desc = projectDescription, !desc.isEmpty {
            result = result.replacingOccurrences(of: "{{PROJECT_DESCRIPTION}}", with: "项目描述：\(desc)")
        } else {
            result = result.replacingOccurrences(of: "{{PROJECT_DESCRIPTION}}", with: "")
        }

        var inputsText = ""
        for (index, input) in inputs.enumerated() {
            inputsText += """

[\(index + 1)] \(input.source ?? "未命名")
\(input.content)
"""
        }
        result = result.replacingOccurrences(of: "{{INPUTS}}", with: inputsText)

        if let cognition = currentCognition {
            result = result.replacingOccurrences(of: "{{CURRENT_COGNITION}}", with: cognition)
        }

        var newInputsText = ""
        for (index, input) in inputs.enumerated() {
            newInputsText += """

[新增 \(index + 1)] \(input.source ?? "未命名")
\(input.content)
"""
        }
        result = result.replacingOccurrences(of: "{{NEW_INPUTS}}", with: newInputsText)

        return result
    }
}
