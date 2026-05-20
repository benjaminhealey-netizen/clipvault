import AppKit

// All top-level setup runs on the main thread — we assert that explicitly
// to satisfy Swift 6 strict concurrency checking.
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate

app.run()
