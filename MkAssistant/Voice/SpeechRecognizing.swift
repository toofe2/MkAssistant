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

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func start(locale: Locale, onPartial: @escaping (String) -> Void, onFinal: @escaping (String) -> Void) throws {
        stop()
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw NSError(domain: "MkAssistant.Speech", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition unavailable"])
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.duckOthers, .allowBluetooth])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        request = req

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in req.append(buffer) }

        task = recognizer.recognitionTask(with: req) { result, error in
            if let result {
                let text = result.bestTranscription.formattedString
                result.isFinal ? onFinal(text) : onPartial(text)
            }
            if error != nil { self.stop() }
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    func stop() {
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
    }
}
