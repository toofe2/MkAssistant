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
    private var audioPlayer: AVAudioPlayer?
    private var audioDelegate: PiperAudioDelegate?
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
                await MainActor.run { self.onDiagnostic?("Piper: synthesizing…") }
                guard let wavPath = await p.synthesizeToFile(text: text) else {
                    throw NSError(domain: "MkAssistant.Piper", code: 20, userInfo: [NSLocalizedDescriptionKey: "Piper did not create a WAV file"])
                }
                let wavURL = URL(fileURLWithPath: wavPath)
                let attrs = try FileManager.default.attributesOfItem(atPath: wavPath)
                let size = (attrs[.size] as? NSNumber)?.intValue ?? 0
                await MainActor.run { self.onDiagnostic?("Piper: WAV ready (\(size) bytes), playing…") }

                try await self.playLegacyCompatibleWAV(wavURL)
                try? FileManager.default.removeItem(at: wavURL)
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


    private func playLegacyCompatibleWAV(_ url: URL) async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                do {
                    let data = try Data(contentsOf: url)
                    guard data.count > 44 else {
                        throw NSError(domain: "MkAssistant.Piper", code: 21, userInfo: [NSLocalizedDescriptionKey: "Generated WAV is empty or invalid"])
                    }
                    let player = try AVAudioPlayer(data: data, fileTypeHint: AVFileType.wav.rawValue)
                    let delegate = PiperAudioDelegate { [weak self] success in
                        guard let self else { return }
                        self.audioPlayer = nil
                        self.audioDelegate = nil
                        if success {
                            continuation.resume()
                        } else {
                            continuation.resume(throwing: NSError(domain: "MkAssistant.Piper", code: 22, userInfo: [NSLocalizedDescriptionKey: "AVAudioPlayer could not play generated WAV"]))
                        }
                    }
                    self.audioDelegate = delegate
                    self.audioPlayer = player
                    player.delegate = delegate
                    player.prepareToPlay()
                    guard player.play() else {
                        self.audioPlayer = nil
                        self.audioDelegate = nil
                        throw NSError(domain: "MkAssistant.Piper", code: 23, userInfo: [NSLocalizedDescriptionKey: "AVAudioPlayer play() returned false"])
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        fallback.stop()
        audioPlayer?.stop()
        audioPlayer = nil
        audioDelegate = nil
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


private final class PiperAudioDelegate: NSObject, AVAudioPlayerDelegate {
    private let completion: (Bool) -> Void
    init(completion: @escaping (Bool) -> Void) {
        self.completion = completion
    }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        completion(flag)
    }
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        completion(false)
    }
}
