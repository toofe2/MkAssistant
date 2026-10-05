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
        self.completion = completion
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language) ?? AVSpeechSynthesisVoice(language: "ar")
        utterance.rate = 0.48
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        completion = nil
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let done = completion
        completion = nil
        done?()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        completion = nil
    }
}
