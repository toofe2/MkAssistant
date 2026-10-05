import Foundation
import AVFoundation

protocol SpeechSynthesizing {
    func speak(_ text: String, language: String)
    func stop()
}

final class AppleSpeechSynthesizer: NSObject, SpeechSynthesizing {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String, language: String = "ar-IQ") {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language) ?? AVSpeechSynthesisVoice(language: "ar")
        utterance.rate = 0.48
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
