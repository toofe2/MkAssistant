import Foundation

@MainActor
final class AssistantController: ObservableObject {
    enum State {
        case idle, requestingPermission, listeningForWakeWord, listening, thinking, speaking, followUp, error(String)

        var label: String {
            switch self {
            case .idle: return "Ready"
            case .requestingPermission: return "Requesting microphone access…"
            case .listeningForWakeWord: return "Waiting for “Hey MK”…"
            case .listening: return "Listening…"
            case .thinking: return "Thinking…"
            case .speaking: return "Speaking…"
            case .followUp: return "Listening for follow-up…"
            case .error(let message): return "Error: \(message)"
            }
        }
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var lastTranscript = ""
    @Published private(set) var lastResponse = ""

    private let wakeWord: WakeWordDetecting
    private let speech: SpeechRecognizing
    private let speaker: SpeechSynthesizing
    private let agent: AssistantAgent
    private var listeningTimeoutTask: Task<Void, Never>?

    init(
        wakeWord: WakeWordDetecting = PlaceholderWakeWordEngine(),
        speech: SpeechRecognizing = AppleSpeechRecognizer(),
        speaker: SpeechSynthesizing = AppleSpeechSynthesizer(),
        agent: AssistantAgent = LocalAssistantAgent()
    ) {
        self.wakeWord = wakeWord
        self.speech = speech
        self.speaker = speaker
        self.agent = agent
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
        armWakeWord()
    }

    private func armWakeWord() {
        state = .listeningForWakeWord
        wakeWord.start { [weak self] in
            Task { @MainActor in self?.beginListening() }
        }
    }

    func testListen() {
        beginListening()
    }

    private func beginListening() {
        listeningTimeoutTask?.cancel()
        speaker.stop()
        speech.stop()
        state = .listening

        do {
            try speech.start(
                locale: Locale(identifier: "ar-IQ"),
                onPartial: { [weak self] text in
                    Task { @MainActor in self?.lastTranscript = text }
                },
                onFinal: { [weak self] text in
                    Task { @MainActor in
                        guard let self else { return }
                        self.lastTranscript = text
                        self.listeningTimeoutTask?.cancel()
                        self.speech.stop()

                        let hasWake = WakePhrase.containsWakeWord(text)
                        let command = WakePhrase.command(afterWakeWord: text)

                        if hasWake && command.isEmpty {
                            await self.acknowledgeWakeWord()
                        } else if hasWake {
                            await self.answer(command)
                        } else {
                            await self.answer(text)
                        }
                    }
                }
            )

            listeningTimeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 12_000_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self else { return }
                    self.speech.stop()
                    self.armWakeWord()
                }
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func acknowledgeWakeWord() async {
        lastResponse = "هلا مصطفى، آني حاضر."
        state = .speaking
        speaker.speak(lastResponse, language: "ar-IQ") { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.state = .followUp
                self.beginListening()
            }
        }
    }

    private func answer(_ transcript: String) async {
        let clean = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            armWakeWord()
            return
        }

        state = .thinking
        do {
            let response = try await agent.respond(to: AssistantRequest(transcript: clean, locale: "ar-IQ"))
            lastResponse = response.spokenText
            state = .speaking
            speaker.speak(response.spokenText, language: "ar-IQ") { [weak self] in
                Task { @MainActor in
                    guard let self else { return }
                    self.state = .followUp
                    self.beginListening()
                }
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func stopListening() {
        listeningTimeoutTask?.cancel()
        speech.stop()
        speaker.stop()
        armWakeWord()
    }
}
