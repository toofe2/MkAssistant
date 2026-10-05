import Foundation
import AVFoundation
import SherpaOnnx

final class SherpaSpeechSynthesizer: SpeechSynthesizing {
    var onDiagnostic: ((String) -> Void)?
    private var tts: SherpaOnnxOfflineTtsWrapper?
    private var engine: AVAudioEngine?
    private var node: AVAudioPlayerNode?
    private var work: DispatchWorkItem?

    func speak(_ text: String, language: String, completion: @escaping () -> Void) {
        stop()
        onDiagnostic?("Sherpa: preparing local Arabic voice…")

        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            do {
                let tts = try self.prepare()
                let sampleRate = Double(tts.sampleRate)
                DispatchQueue.main.async { self.onDiagnostic?("Sherpa: generating Kareem…") }

                let audio = tts.generate(text: text, sid: 0, speed: 1.0)
                guard !audio.samples.isEmpty else {
                    throw NSError(domain: "MkAssistant.Sherpa", code: 31,
                                  userInfo: [NSLocalizedDescriptionKey: "Sherpa generated zero audio samples"])
                }

                let samples = audio.samples
                DispatchQueue.main.async {
                    do {
                        try self.play(samples: samples, sampleRate: sampleRate, completion: completion)
                    } catch {
                        self.onDiagnostic?("Sherpa PLAY ERROR: \(error)")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.onDiagnostic?("Sherpa ERROR: \(error)")
                }
            }
        }
        work = item
        DispatchQueue.global(qos: .userInitiated).async(execute: item)
    }

    private func prepare() throws -> SherpaOnnxOfflineTtsWrapper {
        if let tts { return tts }

        guard let model = Bundle.main.path(forResource: "kareem", ofType: "onnx"),
              let tokens = Bundle.main.path(forResource: "tokens", ofType: "txt"),
              let resources = Bundle.main.resourceURL else {
            throw NSError(domain: "MkAssistant.Sherpa", code: 30,
                          userInfo: [NSLocalizedDescriptionKey: "Bundled Kareem model resources not found"])
        }

        let dataDir = resources.appendingPathComponent("espeak-ng-data").path
        let vits = sherpaOnnxOfflineTtsVitsModelConfig(
            model: model,
            lexicon: "",
            tokens: tokens,
            dataDir: dataDir,
            noiseScale: 0.667,
            noiseScaleW: 0.8,
            lengthScale: 1.0
        )
        let modelConfig = sherpaOnnxOfflineTtsModelConfig(numThreads: 2, vits: vits)
        var config = sherpaOnnxOfflineTtsConfig(model: modelConfig)
        let created = SherpaOnnxOfflineTtsWrapper(config: &config)
        tts = created
        return created
    }

    @MainActor
    private func play(samples: [Float], sampleRate: Double, completion: @escaping () -> Void) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try session.setActive(true)

        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                         sampleRate: sampleRate,
                                         channels: 1,
                                         interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: AVAudioFrameCount(samples.count)) else {
            throw NSError(domain: "MkAssistant.Sherpa", code: 32,
                          userInfo: [NSLocalizedDescriptionKey: "Unable to create audio buffer"])
        }

        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { ptr in
            guard let src = ptr.baseAddress, let dst = buffer.floatChannelData?[0] else { return }
            memcpy(dst, src, samples.count * MemoryLayout<Float>.size)
        }

        let engine = AVAudioEngine()
        let node = AVAudioPlayerNode()
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        try engine.start()

        self.engine = engine
        self.node = node
        onDiagnostic?("Sherpa: speaking locally (\(samples.count) samples)")

        node.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
            DispatchQueue.main.async {
                self?.node?.stop()
                self?.engine?.stop()
                self?.node = nil
                self?.engine = nil
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                completion()
            }
        }
        node.play()
    }

    func stop() {
        work?.cancel()
        work = nil
        node?.stop()
        engine?.stop()
        node = nil
        engine = nil
    }
}
