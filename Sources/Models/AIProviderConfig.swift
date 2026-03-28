import Foundation

enum AIProviderType: String, Codable, CaseIterable {
    case api
    case cli

    var displayName: String {
        switch self {
        case .api:
            return "API"
        case .cli:
            return "CLI"
        }
    }
}

enum CLIOutputDefaults {
    static let commandTemplate = "opencode run {{input}}"
    static let extractionRegex = "(?s)^(?:[ \\t]*\\n)*(?:>[^\\n]*\\n+)?(?!>)([\\s\\S]*)$"
    static let outputTemplate = "{{g1}}"
}

struct AIProviderConfig: Codable, Identifiable {
    let id: UUID
    var name: String
    var providerType: AIProviderType
    var baseURL: String
    var apiKey: String
    var models: [String]
    var defaultModel: String
    var cliCommandTemplate: String
    var cliOutputRegex: String
    var cliOutputTemplate: String
    var isEnabled: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        providerType: AIProviderType = .api,
        baseURL: String,
        apiKey: String,
        models: [String],
        defaultModel: String,
        cliCommandTemplate: String = CLIOutputDefaults.commandTemplate,
        cliOutputRegex: String = CLIOutputDefaults.extractionRegex,
        cliOutputTemplate: String = CLIOutputDefaults.outputTemplate,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.providerType = providerType
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.models = models
        self.defaultModel = defaultModel
        self.cliCommandTemplate = cliCommandTemplate
        self.cliOutputRegex = cliOutputRegex
        self.cliOutputTemplate = cliOutputTemplate
        self.isEnabled = isEnabled
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case providerType
        case baseURL
        case apiKey
        case models
        case defaultModel
        case cliCommandTemplate
        case cliOutputRegex
        case cliOutputTemplate
        case isEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        providerType = try container.decodeIfPresent(AIProviderType.self, forKey: .providerType) ?? .api
        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? ""
        apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
        models = try container.decodeIfPresent([String].self, forKey: .models) ?? []
        defaultModel = try container.decodeIfPresent(String.self, forKey: .defaultModel) ?? ""
        cliCommandTemplate = try container.decodeIfPresent(String.self, forKey: .cliCommandTemplate) ?? CLIOutputDefaults.commandTemplate
        cliOutputRegex = try container.decodeIfPresent(String.self, forKey: .cliOutputRegex) ?? CLIOutputDefaults.extractionRegex
        cliOutputTemplate = try container.decodeIfPresent(String.self, forKey: .cliOutputTemplate) ?? CLIOutputDefaults.outputTemplate
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }
}

// MARK: - Provider Presets

struct ProviderPreset: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let providerType: AIProviderType
    let baseURL: String
    let models: [String]
    let defaultModel: String
    let icon: String
}

extension ProviderPreset {
    static let allPresets: [ProviderPreset] = [
        ProviderPreset(
            name: "OpenAI",
            description: "OpenAI API",
            providerType: .api,
            baseURL: "https://api.openai.com/v1",
            models: ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "gpt-3.5-turbo"],
            defaultModel: "gpt-4o",
            icon: "brain"
        ),
        ProviderPreset(
            name: "Minimax (国际版)",
            description: "Minimax 国际版 API",
            providerType: .api,
            baseURL: "https://api.minimax.io/v1",
            models: ["MiniMax-M2.1", "MiniMax-M2.1-lightning"],
            defaultModel: "MiniMax-M2.1",
            icon: "globe"
        ),
        ProviderPreset(
            name: "Minimax (中国版)",
            description: "Minimax 中国版 API (minimaxi.com)",
            providerType: .api,
            baseURL: "https://api.minimaxi.com/v1",
            models: ["MiniMax-M2.1", "MiniMax-M2.1-lightning"],
            defaultModel: "MiniMax-M2.1",
            icon: "globe"
        ),
        ProviderPreset(
            name: "DeepSeek",
            description: "DeepSeek API",
            providerType: .api,
            baseURL: "https://api.deepseek.com/v1",
            models: ["deepseek-chat", "deepseek-coder"],
            defaultModel: "deepseek-chat",
            icon: "waveform"
        ),
        ProviderPreset(
            name: "阿里云百炼",
            description: "阿里云百炼大模型平台",
            providerType: .api,
            baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1",
            models: ["qwen-plus", "qwen-turbo", "qwen-max"],
            defaultModel: "qwen-plus",
            icon: "cloud"
        ),
        ProviderPreset(
            name: "Azure OpenAI",
            description: "Microsoft Azure OpenAI 服务",
            providerType: .api,
            baseURL: "https://{your-resource}.openai.azure.com/openai/deployments/{deployment-id}",
            models: ["gpt-4o", "gpt-4", "gpt-35-turbo"],
            defaultModel: "gpt-4o",
            icon: "cloud.fill"
        ),
        ProviderPreset(
            name: "Gemini",
            description: "Google Gemini API",
            providerType: .api,
            baseURL: "https://generativelanguage.googleapis.com/v1beta",
            models: ["gemini-1.5-flash", "gemini-1.5-pro"],
            defaultModel: "gemini-1.5-flash",
            icon: "sparkles"
        ),
        ProviderPreset(
            name: "智谱 AI",
            description: "智谱清言 GLM 系列模型",
            providerType: .api,
            baseURL: "https://open.bigmodel.cn/api/paas/v4",
            models: ["glm-4", "glm-4-plus", "glm-4-flash"],
            defaultModel: "glm-4",
            icon: "message.fill"
        ),
        ProviderPreset(
            name: "Kimi",
            description: "月之暗面 Kimi API",
            providerType: .api,
            baseURL: "https://api.moonshot.cn/v1",
            models: ["kimi-k2", "kimi-k2-lite", "kimi-latest"],
            defaultModel: "kimi-k2",
            icon: "moon.fill"
        ),
        ProviderPreset(
            name: "SiliconFlow",
            description: "SiliconFlow 模型聚合平台",
            providerType: .api,
            baseURL: "https://api.siliconflow.cn/v1",
            models: ["deepseek-ai/DeepSeek-V2.5", "Qwen/Qwen2.5-72B-Instruct"],
            defaultModel: "deepseek-ai/DeepSeek-V2.5",
            icon: "cpu"
        ),
        ProviderPreset(
            name: "自定义",
            description: "自定义 OpenAI 兼容 API",
            providerType: .api,
            baseURL: "",
            models: [],
            defaultModel: "",
            icon: "slider.horizontal.3"
        ),
        ProviderPreset(
            name: "Local CLI",
            description: "Run local AI CLI commands",
            providerType: .cli,
            baseURL: "",
            models: [],
            defaultModel: "",
            icon: "terminal"
        )
    ]
}

// MARK: - Helper Extension

extension AIProviderConfig {
    static func fromPreset(_ preset: ProviderPreset) -> AIProviderConfig {
        AIProviderConfig(
            name: preset.name == "自定义" ? "" : preset.name,
            providerType: preset.providerType,
            baseURL: preset.baseURL,
            apiKey: "",
            models: preset.models,
            defaultModel: preset.defaultModel
        )
    }
}

struct AIProviderSelection: Codable {
    var providerId: UUID
    var model: String
}
