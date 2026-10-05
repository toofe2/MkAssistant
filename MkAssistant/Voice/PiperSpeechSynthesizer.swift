import Foundation
import AVFoundation
import piper_player

/// Free, local neural TTS. The Kareem model is downloaded once and cached
/// in Application Support; subsequent speech synthesis is fully on-device.
final class PiperSpeechSynthesizer: SpeechSynthesizing {
    var onDiagnostic: ((String) -> Void)?
    private let fallback = AppleSpeechSynthesizer()
    private var player: PiperPlayer?
    private var task: Task<Void, Never>?
    private let modelManager = PiperKareemModelManager()

    func speak(_ text: String, language: String, completion: @escaping () -> Void) {
        stop()
        task = Task { [weak self] in
            guard let self else { return }
            do {
                await MainActor.run { self.onDiagnostic?("Piper: preparing Kareem model…") }
                let files = try await modelManager.prepare()
                await MainActor.run { self.onDiagnostic?("Piper: model ready") }
                let p: PiperPlayer
                if let player {
                    p = player
                } else {
                    let params = PiperPlayer.Params(
                        modelPath: files.model.path,
                        configPath: files.config.path,
                        espeakNGData: ""
                    )
                    let created = try PiperPlayer(params: params)
                    player = created
                    await MainActor.run { self.onDiagnostic?("Piper: engine ready") }
                    p = created
                }

                let session = AVAudioSession.sharedInstance()
                try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
                try? session.setActive(true)
                await MainActor.run { self.onDiagnostic?("Piper: speaking…") }
                try await p.play(text: text)
                try? session.setActive(false, options: .notifyOthersOnDeactivation)

                if !Task.isCancelled {
                    await MainActor.run { completion() }
                }
            } catch {
                guard !Task.isCancelled else { return }
                let detail = String(describing: error)
                await MainActor.run {
                    self.onDiagnostic?("Piper ERROR: \(detail)")
                    self.fallback.speak(text, language: language, completion: completion)
                }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        fallback.stop()
        if let player {
            Task { await player.stopAndCancel() }
        }
    }
}

private actor PiperKareemModelManager {
    struct Files {
        let model: URL
        let config: URL
    }

    private let modelURL = URL(string: "https://huggingface.co/rhasspy/piper-voices/resolve/main/ar/ar_JO/kareem/medium/ar_JO-kareem-medium.onnx?download=true")!
    private let configURL = URL(string: "https://huggingface.co/rhasspy/piper-voices/resolve/main/ar/ar_JO/kareem/medium/ar_JO-kareem-medium.onnx.json?download=true")!

    func prepare() async throws -> Files {
        let fm = FileManager.default
        let base = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("PiperKareem", isDirectory: true)

        try fm.createDirectory(at: base, withIntermediateDirectories: true)

        let model = base.appendingPathComponent("ar_JO-kareem-medium.onnx")
        let config = base.appendingPathComponent("ar_JO-kareem-medium.onnx.json")

        if !fm.fileExists(atPath: model.path) {
            try await download(modelURL, to: model)
        }
        if !fm.fileExists(atPath: config.path) {
            try await download(configURL, to: config)
        }
        return Files(model: model, config: config)
    }

    private func download(_ remote: URL, to local: URL) async throws {
        let (temporary, response) = try await URLSession.shared.download(from: remote)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        try? FileManager.default.removeItem(at: local)
        try FileManager.default.moveItem(at: temporary, to: local)
    }
}
