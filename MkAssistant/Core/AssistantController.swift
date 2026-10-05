import Foundation

@MainActor
final class AssistantController: ObservableObject {
    enum State {
        case idle, listeningForWakeWord, listening, thinking, speaking, error(String)

        var label: String {
            switch self {
            case .idle: return "Ready"
            case .listeningForWakeWord: return "Waiting for “Hey MK”…"
            case .listening: return "Listening…"
            case .thinking: return "Thinking…"
            case .speaking: return "Speaking…"
            case .error(let message): return "Error: \(message)"
            }
        }
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var lastTranscript = ""
    private let wakeWord: WakeWordDetecting

    init(wakeWord: WakeWordDetecting = PlaceholderWakeWordEngine()) {
        self.wakeWord = wakeWord
    }

    func start() {
        state = .listeningForWakeWord
        wakeWord.start { [weak self] in
            Task { @MainActor in self?.wakeDetected() }
        }
    }

    private func wakeDetected() {
        state = .listening
        // Next milestone: start streaming speech recognition here.
    }
}
