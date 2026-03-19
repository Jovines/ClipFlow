import Foundation

@MainActor
final class FocusTodoAIRewriteService {
    static let shared = FocusTodoAIRewriteService()

    private init() {}

    func generateCandidates(from sourceText: String, maxCount: Int = 4) async throws -> [String] {
        let trimmed = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let prompt = """
        You are an assistant that rewrites messy text into concise, actionable todo tasks.

        Source text:
        \(trimmed)

        Requirements:
        1) Generate \(maxCount) rewrite candidates.
        2) Each candidate should be a single actionable task sentence.
        3) Keep each candidate concise and specific.
        4) Preserve original language from source text when possible.
        5) Return ONLY a JSON array of strings, no markdown, no explanations.
        """

        let response = try await OpenAIService.shared.chat(message: prompt)
        return parseCandidates(from: response, maxCount: maxCount)
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
