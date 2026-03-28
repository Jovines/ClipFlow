import Foundation

@MainActor
final class FocusTodoAIRewriteService {
    static let shared = FocusTodoAIRewriteService()
    private static let defaultMaxCandidates = 4

    private init() {}

    func generateCandidates(from sourceText: String, maxCount: Int? = nil) async throws -> [String] {
        let trimmed = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let candidateLimit = max(1, min(10, maxCount ?? Self.defaultMaxCandidates))

        let prompt = rewritePrompt(from: trimmed, maxCount: candidateLimit)
        let targetProviderId = selectedRewriteProviderId()
        if let providerId = targetProviderId,
           !isProviderAvailable(providerId: providerId) {
            throw OpenAIError.notConfigured
        }

        let response = try await OpenAIService.shared.chat(message: prompt, providerId: targetProviderId)
        return parseCandidates(from: response, maxCount: candidateLimit)
    }

    func isRewriteAvailable() -> Bool {
        if let providerId = selectedRewriteProviderId() {
            return isProviderAvailable(providerId: providerId)
        }
        return OpenAIService.shared.isServiceAvailable
    }

    func rewriteUnavailableMessage() -> String {
        if let providerId = selectedRewriteProviderId() {
            let providers = OpenAIService.shared.availableProviders
            guard providers.contains(where: { $0.id == providerId }) else {
                return "Selected rewrite AI service was not found. Please reselect it in Focus Todo settings.".localized
            }
            return "Selected rewrite AI service is not available. Please check its configuration.".localized
        }
        return "AI service is not configured. Please check AI Service settings.".localized
    }

    private func selectedRewriteProviderId() -> UUID? {
        let raw = UserDefaults.standard.string(forKey: FocusTodoPreferences.rewriteProviderIdKey) ?? FocusTodoPreferences.defaultRewriteProviderId
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return UUID(uuidString: trimmed)
    }

    private func isProviderAvailable(providerId: UUID) -> Bool {
        guard let provider = OpenAIService.shared.availableProviders.first(where: { $0.id == providerId }) else {
            return false
        }

        switch provider.providerType {
        case .api:
            return !provider.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .cli:
            return !provider.cliCommandTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func rewritePrompt(from source: String, maxCount: Int) -> String {
        """
        You are an assistant that rewrites messy text into concise, actionable todo tasks.

        Source text:
        \(source)

        Requirements:
        1) Generate \(maxCount) rewrite candidates.
        2) Each candidate should be a single actionable task sentence.
        3) Keep each candidate concise and specific.
        4) Preserve original language from source text when possible.
        5) Return ONLY a JSON array of strings, no markdown, no explanations.
        """
    }

    private func parseCandidates(from rawResponse: String, maxCount: Int) -> [String] {
        if let parsed = parseJSONArray(from: rawResponse) {
            return normalize(candidates: parsed, maxCount: maxCount)
        }

        if let fencedJSON = extractFencedJSON(from: rawResponse),
           let parsed = parseJSONArray(from: fencedJSON) {
            return normalize(candidates: parsed, maxCount: maxCount)
        }

        return normalize(candidates: parseLines(from: rawResponse), maxCount: maxCount)
    }

    private func parseJSONArray(from text: String) -> [String]? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [Any] else {
            return nil
        }
        return object.compactMap { $0 as? String }
    }

    private func extractFencedJSON(from text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "```(?:json)?\\s*([\\s\\S]*?)\\s*```", options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let innerRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[innerRange])
    }

    private func parseLines(from text: String) -> [String] {
        text
            .split(whereSeparator: \.isNewline)
            .map { line in
                line
                    .replacingOccurrences(of: "^[\\s\\-•*\\d\\.\\)]*", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
    }

    private func normalize(candidates: [String], maxCount: Int) -> [String] {
        var unique: [String] = []
        var seen: Set<String> = []

        for candidate in candidates {
            let cleaned = candidate
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

            guard !cleaned.isEmpty else { continue }
            let key = cleaned.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            unique.append(cleaned)
            if unique.count >= maxCount {
                break
            }
        }

        return unique
    }
}
