import Foundation
import AVFoundation

protocol SpeechSynthesizing {
    func speak(_ text: String, language: String, completion: @escaping () -> Void)
    func stop()
}

final class AppleSpeechSynthesizer: NSObject, SpeechSynthesizing, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var completion: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, language: String = "ar-IQ", completion: @escaping () -> Void) {
        stop()
        self.completion = completion

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            // AVSpeechSynthesizer can still attempt playback with the current route.
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice =
            AVSpeechSynthesisVoice(language: language) ??
            AVSpeechSynthesisVoice(language: "ar-SA") ??
            AVSpeechSynthesisVoice(language: "ar")
        utterance.rate = 0.46
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        completion = nil
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        let done = completion
        completion = nil
        done?()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        completion = nil
    }
}
