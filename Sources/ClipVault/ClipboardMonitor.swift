import AppKit
import Combine

@MainActor
class ClipboardMonitor: ObservableObject {
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    var onNewClip: ((String, ClipType) -> Void)?
    private var ignoreUntil: Date = .distantPast

    func start() {
        lastChangeCount = NSPasteboard.general.changeCount
        let t = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.poll()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func ignoreNext(for duration: TimeInterval = 1.5) {
        ignoreUntil = Date().addingTimeInterval(duration)
    }

    private func poll() {
        let count = NSPasteboard.general.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count
        guard Date() > ignoreUntil else { return }
        guard let text = NSPasteboard.general.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let type = ClipType.detect(text)
        onNewClip?(text, type)
    }
}
