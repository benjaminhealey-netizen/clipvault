import AppKit
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var clips: [Clip] = []
    @Published var searchText: String = ""
    @Published var snippets: [Snippet] = []

    let db: DatabaseManager
    let monitor: ClipboardMonitor
    weak var popoverRef: NSPopover?

    init(db: DatabaseManager, monitor: ClipboardMonitor) {
        self.db = db
        self.monitor = monitor
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
                guard let self = self else { return }
                _ = self.db.addImageClip(data)
                self.loadClips()
            }
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
        popoverRef?.performClose(nil)
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
