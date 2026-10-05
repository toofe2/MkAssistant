import Foundation

protocol WakeWordDetecting {
    func start(onWake: @escaping () -> Void)
    func stop()
}

/// Normalizes the common ways Arabic speech recognition writes "MK".
enum WakePhrase {
    static func normalize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "إ", with: "ا")
            .replacingOccurrences(of: "أ", with: "ا")
            .replacingOccurrences(of: "آ", with: "ا")
            .replacingOccurrences(of: "إم كي", with: "mk")
            .replacingOccurrences(of: "ام كي", with: "mk")
            .replacingOccurrences(of: "ام k", with: "mk")
            .replacingOccurrences(of: "m k", with: "mk")
    }

    static func containsWakeWord(_ text: String) -> Bool {
        let value = normalize(text)
        return value.contains("mk") ||
               value.contains("هاي mk") ||
               value.contains("hey mk")
    }

    static func command(afterWakeWord text: String) -> String {
        var value = normalize(text)
        value = value.replacingOccurrences(of: "hey mk", with: "")
        value = value.replacingOccurrences(of: "هاي mk", with: "")
        value = value.replacingOccurrences(of: "mk", with: "")
        return value.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }
}

/// The production detector remains swappable so a dedicated low-power
/// on-device wake-word model can replace the speech-recognition gate later.
final class PlaceholderWakeWordEngine: WakeWordDetecting {
    private var onWake: (() -> Void)?

    func start(onWake: @escaping () -> Void) {
        self.onWake = onWake
    }

    func stop() {
        onWake = nil
    }
}
