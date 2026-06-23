import AppKit
import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var clips: [Clip] = []
    @Published var searchText: String = ""
    @Published var snippets: [Snippet] = []
    @Published var theme: String = "system"
    @Published var trashScreenshots: Bool = false

    let db: DatabaseManager
    let monitor: ClipboardMonitor
    weak var popoverRef: NSPopover?

    /// Resolves the saved theme string into a SwiftUI override (nil = follow system).
    var colorSchemeOverride: ColorScheme? {
        switch theme {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    func setTheme(_ newTheme: String) {
        theme = newTheme
        db.setSetting("theme", value: newTheme)
    }

    func setTrashScreenshots(_ on: Bool) {
        trashScreenshots = on
        db.setSetting("trashScreenshots", value: on ? "true" : "false")
    }

    init(db: DatabaseManager, monitor: ClipboardMonitor) {
        self.db = db
        self.monitor = monitor
        theme = db.getSetting("theme") ?? "system"
        trashScreenshots = (db.getSetting("trashScreenshots") ?? "false") == "true"
        loadClips()
        loadSnippets()
        monitor.onNewClip = { [weak self] text, type in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                _ = self.db.addClip(content: text, type: type)
                self.loadClips()
            }
        }
        monitor.onNewImage = { [weak self] data in
            Task { @MainActor [weak self] in
                self?.ingestImage(data)
            }
        }
    }

    /// Save an image (clipboard or screenshot) into history and refresh.
    func ingestImage(_ data: Data) {
        _ = db.addImageClip(data)
        loadClips()
    }

    /// Save a screenshot file into history, optionally moving the original to
    /// the Trash (recoverable) once it's safely captured.
    func ingestScreenshot(_ data: Data, sourceURL: URL) {
        ingestImage(data)
        if trashScreenshots {
            try? FileManager.default.trashItem(at: sourceURL, resultingItemURL: nil)
        }
    }

    func loadClips() {
        clips = db.getClips(search: searchText.isEmpty ? nil : searchText)
    }

    func loadSnippets() {
        snippets = db.getSnippets()
    }

    func copyAndClose(_ clip: Clip) {
        monitor.ignoreNext()
        let pb = NSPasteboard.general
        pb.clearContents()
        if clip.type == .image, let data = clip.imageData {
            pb.setData(data, forType: .png)
            if let img = NSImage(data: data), let tiff = img.tiffRepresentation {
                pb.setData(tiff, forType: .tiff)
            }
        } else {
            pb.setString(clip.content, forType: .string)
        }
        db.updateUsage(id: clip.id)
        loadClips()
        popoverRef?.performClose(nil)
    }

    func fireSnippet(slot: Int) {
        guard let s = snippets.first(where: { $0.slot == slot }), !s.content.isEmpty else { return }
        monitor.ignoreNext()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s.content, forType: .string)
        // Surface the snippet as a clip so it appears at the top of the list —
        // the user can see exactly what was just put on the clipboard.
        _ = db.addClip(content: s.content, type: ClipType.detect(s.content))
        loadClips()
        // Keep the popup open so the new top item is visible.
    }

    func deleteClip(_ clip: Clip) {
        db.deleteClip(id: clip.id)
        clips.removeAll { $0.id == clip.id }
    }

    func togglePin(_ clip: Clip) {
        db.pinClip(id: clip.id, pinned: !clip.isPinned)
        loadClips()
    }

    func clearHistory() {
        db.clearHistory()
        loadClips()
    }

    func search(_ text: String) {
        searchText = text
        loadClips()
    }
}
