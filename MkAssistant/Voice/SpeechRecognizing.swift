import Foundation
import Speech
import AVFoundation

protocol SpeechRecognizing {
    func requestAuthorization() async -> Bool
    func start(locale: Locale, onPartial: @escaping (String) -> Void, onFinal: @escaping (String) -> Void) throws
    func stop()
}

final class AppleSpeechRecognizer: SpeechRecognizing {
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silenceTask: Task<Void, Never>?
    private var latestTranscript = ""
    private var deliveredFinal = false
    private var hasTap = false

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func start(locale: Locale, onPartial: @escaping (String) -> Void, onFinal: @escaping (String) -> Void) throws {
        stop()
        deliveredFinal = false
        latestTranscript = ""

        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw NSError(domain: "MkAssistant.Speech", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition unavailable"])
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.duckOthers, .allowBluetooth, .defaultToSpeaker])
        try session.setActive(true)

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        request = req

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in req.append(buffer) }
        hasTap = true

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let text = result.bestTranscription.formattedString
                self.latestTranscript = text
                onPartial(text)

                self.silenceTask?.cancel()

                if result.isFinal {
                    self.deliverFinalOnce(text, onFinal: onFinal)
                } else if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // iOS can keep dictation non-final for a long time. Treat a
                    // short period with no transcript changes as end-of-utterance.
                    self.silenceTask = Task { [weak self] in
                        try? await Task.sleep(nanoseconds: 1_200_000_000)
                        guard !Task.isCancelled, let self else { return }
                        self.deliverFinalOnce(self.latestTranscript, onFinal: onFinal)
                    }
                }
            }

            if error != nil && !self.deliveredFinal && !self.latestTranscript.isEmpty {
                self.deliverFinalOnce(self.latestTranscript, onFinal: onFinal)
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    private func deliverFinalOnce(_ text: String, onFinal: @escaping (String) -> Void) {
        guard !deliveredFinal else { return }
        deliveredFinal = true
        silenceTask?.cancel()
        DispatchQueue.main.async {
            onFinal(text)
        }
    }

    func stop() {
        silenceTask?.cancel()
        silenceTask = nil
        if audioEngine.isRunning { audioEngine.stop() }
        if hasTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasTap = false
        }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
