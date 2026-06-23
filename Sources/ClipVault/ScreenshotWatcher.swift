import AppKit

/// Watches the macOS screenshot save folder and imports new screenshot files
/// into ClipVault. macOS saves screenshots to disk (not the clipboard) by
/// default, so polling the folder is the reliable way to catch them.
@MainActor
final class ScreenshotWatcher {
    var onNewScreenshot: ((Data) -> Void)?

    private var timer: Timer?
    private var directory: URL
    private var namePrefix: String
    private var known: Set<String> = []
    private let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "tiff", "gif", "heic", "pdf"]

    init() {
        // Read the user's screenshot preferences (falls back to macOS defaults).
        let loc = CFPreferencesCopyAppValue("location" as CFString,
                                            "com.apple.screencapture" as CFString) as? String
        let name = CFPreferencesCopyAppValue("name" as CFString,
                                             "com.apple.screencapture" as CFString) as? String

        let path = (loc as NSString?)?.expandingTildeInPath
            ?? FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!.path
        directory = URL(fileURLWithPath: path, isDirectory: true)
        namePrefix = (name?.isEmpty == false) ? name! : "Screenshot"
    }

    func start() {
        // Seed with existing files so we only import shots taken from now on.
        known = Set(currentScreenshotFiles().map { $0.lastPathComponent })

        let t = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.scan() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func currentScreenshotFiles() -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        )) ?? []
        return files.filter {
            $0.lastPathComponent.hasPrefix(namePrefix) &&
            imageExtensions.contains($0.pathExtension.lowercased())
        }
    }

    private func scan() {
        for file in currentScreenshotFiles() {
            let name = file.lastPathComponent
            guard !known.contains(name) else { continue }
            known.insert(name)
            // The file may still be flushing to disk — read a beat later.
            importScreenshot(at: file, retriesLeft: 5)
        }
    }

    private func importScreenshot(at url: URL, retriesLeft: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self = self else { return }
            guard let img = NSImage(contentsOf: url), let png = img.pngData else {
                if retriesLeft > 0 {
                    self.importScreenshot(at: url, retriesLeft: retriesLeft - 1)
                }
                return
            }
            self.onNewScreenshot?(png)
        }
    }
}
