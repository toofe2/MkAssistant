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

final class LocalAssistantAgent: AssistantAgent {
    func respond(to request: AssistantRequest) async throws -> AssistantResponse {
        let text = request.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = text.lowercased()
            .replacingOccurrences(of: "إ", with: "ا")
            .replacingOccurrences(of: "أ", with: "ا")
            .replacingOccurrences(of: "آ", with: "ا")

        // Arabic STT may render “MK” as ام كي / إم كي / m k / ام k.
        let normalized = lower
            .replacingOccurrences(of: "إم كي", with: "mk")
            .replacingOccurrences(of: "ام كي", with: "mk")
            .replacingOccurrences(of: "ام k", with: "mk")
            .replacingOccurrences(of: "m k", with: "mk")

        if normalized.contains("شلونك") || normalized.contains("شخبارك") {
            return AssistantResponse(spokenText: "تمام مصطفى، آني حاضر. شتريد أسويلك؟")
        }
        if normalized.contains("منو انت") || normalized.contains("من انت") {
            return AssistantResponse(spokenText: "آني إم كي، مساعدك الذكي بالسيارة.")
        }
        if normalized.contains("خلاص") || normalized.contains("اسكت") || normalized.contains("stop") {
            return AssistantResponse(spokenText: "تمام.")
        }
        if normalized.contains("هلا") || normalized.contains("مرحبا") || normalized.contains("هاي") || normalized.contains("hello") {
            return AssistantResponse(spokenText: "هلا مصطفى، آني حاضر.")
        }

        return AssistantResponse(spokenText: "سمعتك تقول: \(text)")
    }
}
