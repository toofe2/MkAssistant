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

/// Provider implementation is injected later.
/// API keys must never be committed to the repository.
final class PlaceholderAssistantAgent: AssistantAgent {
    func respond(to request: AssistantRequest) async throws -> AssistantResponse {
        AssistantResponse(spokenText: "سمعتك: \(request.transcript)")
    }
}
