import Foundation
import OpenAI

final class ProjectCognitionService {
    static let shared = ProjectCognitionService()
    
    private init() {}
    
    // MARK: - Generate Initial Cognition
    
    func generateInitialCognition(
        projectName: String,
        projectDescription: String?,
        initialInputs: [(source: String?, content: String)]
    ) async throws -> CognitionResult {
        print("[ProjectCognition] Generating initial cognition for: \(projectName)")
        print("[ProjectCognition] Inputs count: \(initialInputs.count)")
        
        let prompt = buildInitialCognitionPrompt(
            projectName: projectName,
            projectDescription: projectDescription,
            inputs: initialInputs
        )
        
        print("[ProjectCognition] Prompt length: \(prompt.count) characters")
        
        return try await generateCognition(prompt: prompt)
    }
    
    // MARK: - Update Cognition
    
    func updateCognition(
        currentCognition: String,
        projectName: String,
        newInputs: [(source: String?, content: String)]
    ) async throws -> (updatedCognition: String, changeDescription: String) {
        print("[ProjectCognition] Updating cognition for: \(projectName)")
        print("[ProjectCognition] New inputs count: \(newInputs.count)")
        
        let prompt = buildUpdateCognitionPrompt(
            currentCognition: currentCognition,
            projectName: projectName,
            newInputs: newInputs
        )
        
        print("[ProjectCognition] Update prompt length: \(prompt.count) characters")
        
        let result = try await generateCognition(prompt: prompt)
        
        // Generate change description
        let changePrompt = """
        根据以下信息变化，用一句话描述这次更新的核心变化：
        
        原认知文档摘要：\(extractSummary(from: currentCognition))
        
        新认知文档摘要：\(result.summary)
        
        请用一句话描述这次更新的核心变化（如："识别出性能瓶颈问题"、"明确了缓存策略"等）：
        """
        
        print("[ProjectCognition] Generating change description...")
        let changeDescription = try await OpenAIService.shared.chat(message: changePrompt)
        
        print("[ProjectCognition] Change description: \(changeDescription)")
        
        return (result.fullContent, changeDescription.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    // MARK: - Analysis Cards
    
    func analyzeInput(
        content: String,
        projectContext: String?
    ) async throws -> AnalysisCard {
        let prompt = """
        分析以下讨论内容，提供结构化分析：
        
        内容：\(content)
        
        \(projectContext.map { "项目背景：\($0)" } ?? "")
        
        请提供以下分析（使用中文）：
        
        1. 核心观点：对方想表达什么？
        2. 关注点：涉及哪些方面/问题？
        3. 态度：建设性/质疑/确认/其他？
        4. 回复建议：提供3个可能的回复方向
        5. 关键信息：提取关键词和重要信息
        
        以结构化格式输出。
        """
        
        let response = try await OpenAIService.shared.chat(message: prompt)
        return parseAnalysisCard(from: response, content: content)
    }
    
    // MARK: - Private Methods
    
    private func generateCognition(prompt: String) async throws -> CognitionResult {
        print("[ProjectCognition] Calling AI service...")
        
        do {
            let response = try await OpenAIService.shared.chat(message: prompt)
            print("[ProjectCognition] AI response received, length: \(response.count)")
            return parseCognitionResponse(response)
        } catch {
            print("[ProjectCognition] ❌ AI call failed: \(error)")
            throw error
        }
    }
    
    private func buildInitialCognitionPrompt(
        projectName: String,
        projectDescription: String?,
        inputs: [(source: String?, content: String)]
    ) -> String {
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
        4. 用一句话总结整个文档的核心要点（放在开头）
        
        请直接输出Markdown格式的认知文档。
        """
        
        return prompt
    }
    
    private func buildUpdateCognitionPrompt(
        currentCognition: String,
        projectName: String,
        newInputs: [(source: String?, content: String)]
    ) -> String {
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
        1. 保持原有结构（项目背景、当前理解、待确认事项、关键结论）
        2. 根据新信息更新内容
        3. 新增信息可以：
           - 补充现有内容
           - 修正已有理解
           - 添加新的待确认事项
           - 形成新的结论
        4. 用一句话总结这次更新的核心变化（放在文档开头）
        5. 在文档末尾用 <!-- CHANGE: xxx --> 标注主要变化点
        
        请输出更新后的完整Markdown文档。
        """
        
        return prompt
    }
    
    private func parseCognitionResponse(_ response: String) -> CognitionResult {
        print("[ProjectCognition] Parsing AI response...")
        
        // Extract summary (first line or sentence)
        let lines = response.components(separatedBy: .newlines)
        let summary = lines.first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? "暂无摘要"
        
        print("[ProjectCognition] Extracted summary: \(summary.prefix(50))...")
        
        // Extract sections
        let background = extractSection(from: response, sectionName: "项目背景")
        let currentUnderstanding = extractSection(from: response, sectionName: "当前理解")
        let pendingItems = extractSection(from: response, sectionName: "待确认事项")
        let keyConclusions = extractSection(from: response, sectionName: "关键结论")
        
        print("[ProjectCognition] Sections - Background: \(background != nil), Understanding: \(currentUnderstanding != nil), Pending: \(pendingItems != nil), Conclusions: \(keyConclusions != nil)")
        
        return CognitionResult(
            summary: summary,
            fullContent: response,
            background: background,
            currentUnderstanding: currentUnderstanding,
            pendingItems: pendingItems,
            keyConclusions: keyConclusions
        )
    }
    
    private func extractSection(from content: String, sectionName: String) -> String? {
        let pattern = "##\\s*" + NSRegularExpression.escapedPattern(for: sectionName) + "\\s*\\n(.*?)\\n(?=##|\\Z)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return nil
        }
        
        let range = NSRange(content.startIndex..., in: content)
        if let match = regex.firstMatch(in: content, options: [], range: range) {
            let sectionRange = match.range(at: 1)
            if let swiftRange = Range(sectionRange, in: content) {
                return String(content[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return nil
    }
    
    private func extractSummary(from content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        return lines.first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? "暂无摘要"
    }
    
    private func parseAnalysisCard(from response: String, content: String) -> AnalysisCard {
        // Simple parsing - can be improved with structured output
        let lines = response.components(separatedBy: .newlines)
        
        var coreView = ""
        var focus = ""
        var attitude = ""
        var replySuggestions: [String] = []
        var keyInfo = ""
        
        var currentSection = ""
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.contains("核心观点") || trimmed.contains("1.") {
                currentSection = "core"
                continue
            } else if trimmed.contains("关注点") || trimmed.contains("2.") {
                currentSection = "focus"
                continue
            } else if trimmed.contains("态度") || trimmed.contains("3.") {
                currentSection = "attitude"
                continue
            } else if trimmed.contains("回复建议") || trimmed.contains("4.") {
                currentSection = "reply"
                continue
            } else if trimmed.contains("关键信息") || trimmed.contains("5.") {
                currentSection = "keyinfo"
                continue
            }
            
            if !trimmed.isEmpty && !trimmed.hasPrefix("-") {
                switch currentSection {
                case "core":
                    coreView = trimmed
                case "focus":
                    focus = trimmed
                case "attitude":
                    attitude = trimmed
                case "reply":
                    if trimmed.hasPrefix("-") || trimmed.hasPrefix("1.") || trimmed.hasPrefix("2.") || trimmed.hasPrefix("3.") {
                        replySuggestions.append(trimmed)
                    }
                case "keyinfo":
                    keyInfo = trimmed
                default:
                    break
                }
            }
        }
        
        return AnalysisCard(
            originalContent: content,
            coreView: coreView.isEmpty ? "分析中..." : coreView,
            focus: focus.isEmpty ? "未明确" : focus,
            attitude: attitude.isEmpty ? "待判断" : attitude,
            replySuggestions: replySuggestions.isEmpty ? ["1. 感谢反馈，我们会认真考虑", "2. 能否详细说明一下？", "3. 这个建议很好"] : replySuggestions,
            keyInfo: keyInfo.isEmpty ? "待提取" : keyInfo
        )
    }
}

// MARK: - Result Types

struct CognitionResult {
    let summary: String
    let fullContent: String
    let background: String?
    let currentUnderstanding: String?
    let pendingItems: String?
    let keyConclusions: String?
}

struct AnalysisCard {
    let originalContent: String
    let coreView: String
    let focus: String
    let attitude: String
    let replySuggestions: [String]
    let keyInfo: String
}
