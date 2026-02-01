import Foundation
import OpenAI

struct ProjectPromptTemplate {
    let name: String
    let description: String
    let initialPrompt: String
    let updatePrompt: String
}

struct ProjectPromptTemplates {
    static let defaultTemplate = ProjectPromptTemplate(
        name: "默认模板",
        description: "标准的项目认知文档生成模板",
        initialPrompt: INITIAL_PROMPT_TEMPLATE,
        updatePrompt: UPDATE_PROMPT_TEMPLATE
    )

    static let meetingNotes = ProjectPromptTemplate(
        name: "会议记录",
        description: "专门用于整理会议讨论内容",
        initialPrompt: MEETING_NOTES_INITIAL_PROMPT,
        updatePrompt: MEETING_NOTES_UPDATE_PROMPT
    )

    static let technicalDesign = ProjectPromptTemplate(
        name: "技术设计",
        description: "技术方案设计与讨论",
        initialPrompt: TECHNICAL_DESIGN_INITIAL_PROMPT,
        updatePrompt: TECHNICAL_DESIGN_UPDATE_PROMPT
    )

    static let allTemplates: [ProjectPromptTemplate] = [defaultTemplate, meetingNotes, technicalDesign]

    static func template(named name: String) -> ProjectPromptTemplate? {
        allTemplates.first { $0.name == name }
    }
}

private let INITIAL_PROMPT_TEMPLATE = """
你是一个项目管理助手，负责整理和分析项目讨论内容。

项目名称：{{PROJECT_NAME}}
{{PROJECT_DESCRIPTION}}

初始讨论素材：
{{INPUTS}}

请根据以上内容，生成一份项目认知文档（Markdown格式），包含：

# {{PROJECT_NAME}}

## 摘要
用一句话总结整个文档的核心要点

## 项目背景
简要描述项目的起因和目标

## 当前理解
### 核心目标
列出当前理解的项目核心目标

### 已识别问题/挑战
列出已识别的问题或待解决事项

### 讨论进展
简述目前的讨论状态和进展

## 待确认事项
列出需要进一步明确或确认的事项

## 关键结论
列出已达成的一致或重要结论

要求：
1. 使用专业的项目管理语言
2. 保持客观，不要添加未提及的信息
3. 如果信息不足，标注为"待补充"

请直接输出Markdown格式的认知文档。
"""

private let UPDATE_PROMPT_TEMPLATE = """
你是一个项目管理助手，需要更新现有的项目认知文档。

当前认知文档：
{{CURRENT_COGNITION}}

新增讨论素材：
{{NEW_INPUTS}}

请整合新增素材，更新项目认知文档（Markdown格式）：

要求：
1. 保持原有结构
2. 根据新信息更新内容
3. 用一句话总结这次更新的核心变化（放在文档开头）

请输出更新后的完整Markdown文档。
"""

private let MEETING_NOTES_INITIAL_PROMPT = """
你是一个会议记录助手，负责整理和分析会议讨论内容。

会议主题：{{PROJECT_NAME}}
{{PROJECT_DESCRIPTION}}

会议讨论内容：
{{INPUTS}}

请根据以上内容，生成一份结构化的会议纪要（Markdown格式），包含：

# {{PROJECT_NAME}}

## 会议概览
- 会议时间：待补充
- 参会人员：待补充
- 会议目的：简述会议的主要目的

## 讨论要点
### 议题一：xxx
- 主要观点：
- 达成共识：
- 待办事项：

## 决策事项
列出会议上做出的决定

## 行动项
列出需要跟进的任务和负责人

## 待讨论问题
列出需要下次会议讨论的问题

要求：
1. 条理清晰，重点突出
2. 准确记录各方观点
3. 区分"已决议"和"待讨论"事项

请直接输出Markdown格式的会议纪要。
"""

private let MEETING_NOTES_UPDATE_PROMPT = """
你是一个会议记录助手，需要更新会议纪要。

当前会议纪要：
{{CURRENT_COGNITION}}

新增讨论内容：
{{NEW_INPUTS}}

请整合新增内容，更新会议纪要（Markdown格式）：

要求：
1. 保持原有结构
2. 将新内容正确插入相应章节
3. 更新决策和行动项状态
4. 用一句话总结这次会议的核心变化（放在文档开头）

请输出更新后的完整Markdown文档。
"""

private let TECHNICAL_DESIGN_INITIAL_PROMPT = """
你是一个技术架构师，负责整理和分析技术方案讨论。

项目名称：{{PROJECT_NAME}}
{{PROJECT_DESCRIPTION}}

技术方案讨论素材：
{{INPUTS}}

请根据以上内容，生成一份技术设计文档（Markdown格式），包含：

# {{PROJECT_NAME}} 技术方案

## 概述
用一句话总结技术方案的核心要点

## 背景与目标
### 业务背景
描述技术方案的业务驱动因素
### 设计目标
列出技术方案要实现的目标
### 约束条件
列出技术约束和限制

## 架构设计
### 整体架构
描述系统整体架构
### 核心模块
列出核心模块及其职责
### 数据模型
描述关键数据结构

## 技术选型
### 选型理由
说明技术选型的考量因素
### 替代方案
列出考虑过的替代方案及放弃原因

## 接口设计
### API 概览
列出主要 API
### 接口详情
描述关键接口的请求/响应

## 实施计划
### 阶段划分
分阶段实施计划
### 风险与应对
识别技术风险及应对措施

要求：
1. 技术描述准确、详细
2. 包含必要的架构图说明（用文字描述）
3. 考虑扩展性和维护性

请直接输出Markdown格式的技术设计文档。
"""

private let TECHNICAL_DESIGN_UPDATE_PROMPT = """
你是一个技术架构师，需要更新技术设计文档。

当前技术设计文档：
{{CURRENT_COGNITION}}

新增讨论素材：
{{NEW_INPUTS}}

请整合新增素材，更新技术设计文档（Markdown格式）：

要求：
1. 保持原有结构
2. 根据新讨论更新技术方案
3. 标注需要重新评审的章节
4. 用一句话总结这次更新的核心变化（放在文档开头）

请输出更新后的完整Markdown文档。
"""

final class ProjectCognitionService {
    static let shared = ProjectCognitionService()

    private init() {}

    func generateInitialCognition(
        projectName: String,
        projectDescription: String?,
        initialInputs: [(source: String?, content: String)],
        customPrompt: String? = nil
    ) async throws -> String {
        print("[ProjectCognition] Generating initial cognition for: \(projectName)")
        print("[ProjectCognition] Inputs count: \(initialInputs.count)")

        let prompt = buildInitialCognitionPrompt(
            projectName: projectName,
            projectDescription: projectDescription,
            inputs: initialInputs,
            customPrompt: customPrompt
        )

        print("[ProjectCognition] Prompt length: \(prompt.count) characters")

        return try await generateCognition(prompt: prompt)
    }

    func updateCognition(
        currentCognition: String,
        projectName: String,
        newInputs: [(source: String?, content: String)],
        customPrompt: String? = nil
    ) async throws -> (updatedCognition: String, changeDescription: String) {
        print("[ProjectCognition] Updating cognition for: \(projectName)")
        print("[ProjectCognition] New inputs count: \(newInputs.count)")

        let prompt = buildUpdateCognitionPrompt(
            currentCognition: currentCognition,
            projectName: projectName,
            newInputs: newInputs,
            customPrompt: customPrompt
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
        customPrompt: String? = nil
    ) -> String {
        if let customPrompt = customPrompt, !customPrompt.isEmpty {
            return fillPromptTemplate(
                template: customPrompt,
                projectName: projectName,
                projectDescription: projectDescription,
                inputs: inputs,
                currentCognition: nil
            )
        }

        var prompt = """
        你是一个项目管理助手，负责整理和分析项目讨论内容。

        项目名称：\(projectName)
        \(projectDescription?.isEmpty == false ? "项目描述：\(projectDescription!)" : "")

        初始讨论素材：
        """

        for (index, input) in inputs.enumerated() {
            prompt += """
            \n\n[\(index + 1)] \(input.source ?? "未命名")
            \(input.content)
            """
        }

        prompt += """
        \n\n请根据以上内容，生成一份项目认知文档（Markdown格式），包含：

        # \(projectName)

        ## 摘要
        用一句话总结整个文档的核心要点

        ## 项目背景
        简要描述项目的起因和目标

        ## 当前理解
        ### 核心目标
        列出当前理解的项目核心目标

        ### 已识别问题/挑战
        列出已识别的问题或待解决事项

        ### 讨论进展
        简述目前的讨论状态和进展

        ## 待确认事项
        列出需要进一步明确或确认的事项

        ## 关键结论
        列出已达成的一致或重要结论

        要求：
        1. 使用专业的项目管理语言
        2. 保持客观，不要添加未提及的信息
        3. 如果信息不足，标注为"待补充"

        请直接输出Markdown格式的认知文档。
        """

        return prompt
    }

    private func buildUpdateCognitionPrompt(
        currentCognition: String,
        projectName: String,
        newInputs: [(source: String?, content: String)],
        customPrompt: String? = nil
    ) -> String {
        if let customPrompt = customPrompt, !customPrompt.isEmpty {
            return fillPromptTemplate(
                template: customPrompt,
                projectName: projectName,
                projectDescription: nil,
                inputs: newInputs,
                currentCognition: currentCognition
            )
        }

        var prompt = """
        你是一个项目管理助手，需要更新现有的项目认知文档。

        当前认知文档：
        \(currentCognition)

        新增讨论素材：
        """

        for (index, input) in newInputs.enumerated() {
            prompt += """
            \n\n[新增 \(index + 1)] \(input.source ?? "未命名")
            \(input.content)
            """
        }

        prompt += """
        \n\n请整合新增素材，更新项目认知文档（Markdown格式）：

        要求：
        1. 保持原有结构
        2. 根据新信息更新内容
        3. 用一句话总结这次更新的核心变化（放在文档开头）

        请输出更新后的完整Markdown文档。
        """

        return prompt
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
            \n\n[\(index + 1)] \(input.source ?? "未命名")
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
            \n\n[新增 \(index + 1)] \(input.source ?? "未命名")
            \(input.content)
            """
        }
        result = result.replacingOccurrences(of: "{{NEW_INPUTS}}", with: newInputsText)

        return result
    }
}
