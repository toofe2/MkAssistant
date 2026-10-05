import Foundation

protocol WakeWordDetecting {
    func start(onWake: @escaping () -> Void)
    func stop()
}

/// Placeholder. Replaced by the real on-device wake-word engine after
/// microphone/background behavior is validated on the target iPhone.
final class PlaceholderWakeWordEngine: WakeWordDetecting {
    private var onWake: (() -> Void)?

    func start(onWake: @escaping () -> Void) {
        self.onWake = onWake
    }

    func stop() {
        onWake = nil
    }
}
