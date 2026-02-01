import Foundation
import GRDB

struct PromptTemplate: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var description: String
    var initialPrompt: String
    var updatePrompt: String
    var isSystem: Bool
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case initialPrompt
        case updatePrompt
        case isSystem
        case createdAt
        case updatedAt
    }

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        initialPrompt: String,
        updatePrompt: String,
        isSystem: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.initialPrompt = initialPrompt
        self.updatePrompt = updatePrompt
        self.isSystem = isSystem
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension PromptTemplate {
    init(from record: PromptTemplateRecord) {
        self.id = record.id
        self.name = record.name
        self.description = record.description
        self.initialPrompt = record.initialPrompt
        self.updatePrompt = record.updatePrompt
        self.isSystem = record.isSystem
        self.createdAt = record.createdAt
        self.updatedAt = record.updatedAt
    }
}

struct PromptTemplateRecord: Codable {
    let id: UUID
    var name: String
    var description: String
    var initialPrompt: String
    var updatePrompt: String
    var isSystem: Bool
    var createdAt: Date
    var updatedAt: Date

    init(from template: PromptTemplate) {
        self.id = template.id
        self.name = template.name
        self.description = template.description
        self.initialPrompt = template.initialPrompt
        self.updatePrompt = template.updatePrompt
        self.isSystem = template.isSystem
        self.createdAt = template.createdAt
        self.updatedAt = template.updatedAt
    }

    init(
        id: UUID,
        name: String,
        description: String,
        initialPrompt: String,
        updatePrompt: String,
        isSystem: Bool,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.initialPrompt = initialPrompt
        self.updatePrompt = updatePrompt
        self.isSystem = isSystem
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension PromptTemplateRecord: FetchableRecord, PersistableRecord {
    static let databaseTableName = "prompt_templates"

    enum Columns {
        static let id = Column("id")
        static let name = Column("name")
        static let description = Column("description")
        static let initialPrompt = Column("initialPrompt")
        static let updatePrompt = Column("updatePrompt")
        static let isSystem = Column("isSystem")
        static let createdAt = Column("createdAt")
        static let updatedAt = Column("updatedAt")
    }

    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.id] = id
        container[Columns.name] = name
        container[Columns.description] = description
        container[Columns.initialPrompt] = initialPrompt
        container[Columns.updatePrompt] = updatePrompt
        container[Columns.isSystem] = isSystem
        container[Columns.createdAt] = createdAt
        container[Columns.updatedAt] = updatedAt
    }
}

struct SystemPromptTemplates {
    static let `default` = PromptTemplate(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "默认模板",
        description: "标准的项目认知文档生成模板",
        initialPrompt: INITIAL_PROMPT_TEMPLATE,
        updatePrompt: UPDATE_PROMPT_TEMPLATE,
        isSystem: true
    )

    static let meetingNotes = PromptTemplate(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "会议记录",
        description: "专门用于整理会议讨论内容",
        initialPrompt: MEETING_NOTES_INITIAL_PROMPT,
        updatePrompt: MEETING_NOTES_UPDATE_PROMPT,
        isSystem: true
    )

    static let technicalDesign = PromptTemplate(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        name: "技术设计",
        description: "技术方案设计与讨论",
        initialPrompt: TECHNICAL_DESIGN_INITIAL_PROMPT,
        updatePrompt: TECHNICAL_DESIGN_UPDATE_PROMPT,
        isSystem: true
    )

    static let all: [PromptTemplate] = [`default`, meetingNotes, technicalDesign]

    static func template(for id: UUID) -> PromptTemplate? {
        all.first { $0.id == id }
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
