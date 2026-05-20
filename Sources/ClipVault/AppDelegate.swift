import AppKit
import SwiftUI
import Carbon

// MARK: - Global hotkey state (file-level, accessible from C callback)

// Hotkey IDs: 1 = Cmd+Shift+V toggle, 101–109 = Cmd+1–9 snippets
private var globalHotkeyRefs: [EventHotKeyRef?] = Array(repeating: nil, count: 11)
nonisolated(unsafe) private var appDelegateRef: AppDelegate?

// US-keyboard key codes for digits 1–9
private let digitKeyCodes: [UInt32] = [18, 19, 20, 21, 23, 22, 26, 28, 25]

// Carbon event handler must be a @convention(c) function
private func hotkeyEventHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    var hkID = EventHotKeyID()
    GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hkID
    )
    Task { @MainActor in
        if hkID.id == 1 {
            appDelegateRef?.togglePopover()
        } else if hkID.id >= 101 && hkID.id <= 109 {
            let slot = Int(hkID.id) - 100  // 101 → slot 1 … 109 → slot 9
            appDelegateRef?.appState?.fireSnippet(slot: slot)
        }
    }
    return noErr
}

// MARK: - AppDelegate

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var appState: AppState!
    var db: DatabaseManager!
    var monitor: ClipboardMonitor!
    var settingsWindow: NSWindow?
    private var eventHandlerRef: EventHandlerRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        appDelegateRef = self

        // Setup database and monitor
        db = DatabaseManager()
        monitor = ClipboardMonitor()

        // Setup app state
        appState = AppState(db: db, monitor: monitor)

        // Setup status bar item
        setupStatusItem()

        // Setup popover
        setupPopover()

        // Start clipboard monitoring
        monitor.start()

        // Register global hotkeys (Cmd+Shift+V + Cmd+1–9)
        registerHotkeys()

        // Listen for settings notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSettings),
            name: .openSettings,
            object: nil
        )
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
            if let img = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "ClipVault") {
                let configured = img.withSymbolConfiguration(config) ?? img
                configured.isTemplate = true
                button.image = configured
            }
            button.action = #selector(statusButtonClicked)
            button.target = self
            button.toolTip = "ClipVault (⌘⇧V)"
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 380, height: 520)
        popover.behavior = .transient
        popover.animates = true

        let hostingController = NSHostingController(rootView: PopupView(state: appState))
        popover.contentViewController = hostingController
        appState.popoverRef = popover
    }

    @objc func statusButtonClicked() {
        togglePopover()
    }

    func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            guard let button = statusItem.button else { return }
            appState.loadClips()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func registerHotkeys() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        // Install the C-convention handler (one install covers all hotkeys)
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyEventHandler,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        let sig = OSType(0x4356_4C54) // 'CVLT'

        // Cmd+Shift+V → toggle popup (id = 1)
        var hkID = EventHotKeyID(signature: sig, id: 1)
        RegisterEventHotKey(9, UInt32(cmdKey | shiftKey), hkID, GetApplicationEventTarget(), 0, &globalHotkeyRefs[0])

        // Cmd+1–9 → snippets (id = 101–109)
        for (i, keyCode) in digitKeyCodes.enumerated() {
            hkID = EventHotKeyID(signature: sig, id: UInt32(101 + i))
            RegisterEventHotKey(keyCode, UInt32(cmdKey), hkID, GetApplicationEventTarget(), 0, &globalHotkeyRefs[i + 1])
        }
    }

    @objc func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(state: appState)
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "ClipVault Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        window.setContentSize(NSSize(width: 480, height: 600))

        settingsWindow = window

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.settingsWindow = nil }
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        for ref in globalHotkeyRefs { if let r = ref { UnregisterEventHotKey(r) } }
        if let ref = eventHandlerRef { RemoveEventHandler(ref) }
    }
}
