import AppKit
import Combine

@MainActor
class ClipboardMonitor: ObservableObject {
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    var onNewClip: ((String, ClipType) -> Void)?
    var onNewImage: ((Data) -> Void)?
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
        let pb = NSPasteboard.general
        let count = pb.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count
        guard Date() > ignoreUntil else { return }

        let types = pb.types ?? []

        // Prefer text when present (covers copied URLs that also carry an icon),
        // but treat a pure image copy (screenshot, image from a browser) as an image.
        if let text = pb.string(forType: .string),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            onNewClip?(text, ClipType.detect(text))
            return
        }

        // Image: normalise whatever the source provided into PNG bytes.
        if types.contains(.png) || types.contains(.tiff),
           let img = NSImage(pasteboard: pb),
           let png = img.pngData {
            onNewImage?(png)
        }
    }
}

extension NSImage {
    /// Lossless PNG representation of the image's bitmap data.
    var pngData: Data? {
        guard let tiff = tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
