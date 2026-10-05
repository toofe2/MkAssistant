import Foundation

struct AssistantRequest {
    let transcript: String
    let locale: String
}

struct AssistantResponse {
    let spokenText: String
}

protocol AssistantAgent {
    func respond(to request: AssistantRequest) async throws -> AssistantResponse
}

/// Local Phase-1 brain used to validate the complete voice loop without
/// requiring an API key. It will be replaced by the streaming AI provider.
final class LocalAssistantAgent: AssistantAgent {
    func respond(to request: AssistantRequest) async throws -> AssistantResponse {
        let text = request.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = text.lowercased()

        if lower.contains("شلونك") || lower.contains("شخبارك") {
            return AssistantResponse(spokenText: "تمام مصطفى، آني حاضر. شتريد أسويلك؟")
        }
        if lower.contains("منو انت") || lower.contains("من أنت") {
            return AssistantResponse(spokenText: "آني إم كي، مساعدك الذكي بالسيارة.")
        }
        if lower.contains("خلاص") || lower.contains("اسكت") || lower.contains("stop") {
            return AssistantResponse(spokenText: "تمام.")
        }

        return AssistantResponse(spokenText: "سمعتك تقول: \(text)")
    }
}
