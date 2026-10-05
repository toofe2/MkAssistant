import Foundation

@MainActor
final class AssistantController: ObservableObject {
    enum State {
        case idle, requestingPermission, listeningForWakeWord, listening, thinking, speaking, error(String)

        var label: String {
            switch self {
            case .idle: return "Ready"
            case .requestingPermission: return "Requesting microphone access…"
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
    private let speech: SpeechRecognizing
    private let speaker: SpeechSynthesizing

    init(
        wakeWord: WakeWordDetecting = PlaceholderWakeWordEngine(),
        speech: SpeechRecognizing = AppleSpeechRecognizer(),
        speaker: SpeechSynthesizing = AppleSpeechSynthesizer()
    ) {
        self.wakeWord = wakeWord
        self.speech = speech
        self.speaker = speaker
    }

    func start() {
        Task { await prepareVoice() }
    }

    private func prepareVoice() async {
        state = .requestingPermission
        guard await speech.requestAuthorization() else {
            state = .error("Speech recognition permission denied")
            return
        }
        state = .listeningForWakeWord
        wakeWord.start { [weak self] in
            Task { @MainActor in self?.wakeDetected() }
        }
    }

    /// Temporary test path for Phase 1. The UI can call this before the
    /// production wake-word engine is installed.
    func testListen() {
        beginListening()
    }

    private func wakeDetected() {
        beginListening()
    }

    private func beginListening() {
        speaker.stop()
        state = .listening
        do {
            try speech.start(
                locale: Locale(identifier: "ar-IQ"),
                onPartial: { [weak self] text in
                    Task { @MainActor in self?.lastTranscript = text }
                },
                onFinal: { [weak self] text in
                    Task { @MainActor in
                        self?.lastTranscript = text
                        self?.state = .thinking
                    }
                }
            )
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func stopListening() {
        speech.stop()
        state = .listeningForWakeWord
    }
}
