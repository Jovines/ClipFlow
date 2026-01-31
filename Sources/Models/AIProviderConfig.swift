import Foundation

struct AIProviderConfig: Codable, Identifiable {
    let id: UUID
    var name: String
    var baseURL: String
    var apiKey: String
    var models: [String]
    var defaultModel: String
    var isEnabled: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        baseURL: String,
        apiKey: String,
        models: [String],
        defaultModel: String,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.models = models
        self.defaultModel = defaultModel
        self.isEnabled = isEnabled
    }
}

// MARK: - Provider Presets

struct ProviderPreset: Identifiable {
    let id = UUID()
    let name: String
    let description: String
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
            baseURL: "https://api.openai.com/v1",
            models: ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "gpt-3.5-turbo"],
            defaultModel: "gpt-4o",
            icon: "brain"
        ),
        ProviderPreset(
            name: "Minimax (国际版)",
            description: "Minimax 国际版 API",
            baseURL: "https://api.minimax.io/v1",
            models: ["MiniMax-M2.1", "MiniMax-M2.1-lightning"],
            defaultModel: "MiniMax-M2.1",
            icon: "globe"
        ),
        ProviderPreset(
            name: "Minimax (中国版)",
            description: "Minimax 中国版 API (minimaxi.com)",
            baseURL: "https://api.minimaxi.com/v1",
            models: ["MiniMax-M2.1", "MiniMax-M2.1-lightning"],
            defaultModel: "MiniMax-M2.1",
            icon: "globe"
        ),
        ProviderPreset(
            name: "DeepSeek",
            description: "DeepSeek API",
            baseURL: "https://api.deepseek.com/v1",
            models: ["deepseek-chat", "deepseek-coder"],
            defaultModel: "deepseek-chat",
            icon: "waveform"
        ),
        ProviderPreset(
            name: "阿里云百炼",
            description: "阿里云百炼大模型平台",
            baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1",
            models: ["qwen-plus", "qwen-turbo", "qwen-max"],
            defaultModel: "qwen-plus",
            icon: "cloud"
        ),
        ProviderPreset(
            name: "Azure OpenAI",
            description: "Microsoft Azure OpenAI 服务",
            baseURL: "https://{your-resource}.openai.azure.com/openai/deployments/{deployment-id}",
            models: ["gpt-4o", "gpt-4", "gpt-35-turbo"],
            defaultModel: "gpt-4o",
            icon: "cloud.fill"
        ),
        ProviderPreset(
            name: "Gemini",
            description: "Google Gemini API",
            baseURL: "https://generativelanguage.googleapis.com/v1beta",
            models: ["gemini-1.5-flash", "gemini-1.5-pro"],
            defaultModel: "gemini-1.5-flash",
            icon: "sparkles"
        ),
        ProviderPreset(
            name: "智谱 AI",
            description: "智谱清言 GLM 系列模型",
            baseURL: "https://open.bigmodel.cn/api/paas/v4",
            models: ["glm-4", "glm-4-plus", "glm-4-flash"],
            defaultModel: "glm-4",
            icon: "message.fill"
        ),
        ProviderPreset(
            name: "Kimi",
            description: "月之暗面 Kimi API",
            baseURL: "https://api.moonshot.cn/v1",
            models: ["kimi-k2", "kimi-k2-lite", "kimi-latest"],
            defaultModel: "kimi-k2",
            icon: "moon.fill"
        ),
        ProviderPreset(
            name: "SiliconFlow",
            description: "SiliconFlow 模型聚合平台",
            baseURL: "https://api.siliconflow.cn/v1",
            models: ["deepseek-ai/DeepSeek-V2.5", "Qwen/Qwen2.5-72B-Instruct"],
            defaultModel: "deepseek-ai/DeepSeek-V2.5",
            icon: "cpu"
        ),
        ProviderPreset(
            name: "自定义",
            description: "自定义 OpenAI 兼容 API",
            baseURL: "",
            models: [],
            defaultModel: "",
            icon: "slider.horizontal.3"
        )
    ]
}

// MARK: - Helper Extension

extension AIProviderConfig {
    static func fromPreset(_ preset: ProviderPreset) -> AIProviderConfig {
        AIProviderConfig(
            name: preset.name == "自定义" ? "" : preset.name,
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
