<div align="center">

# 📋 ClipVault

**A fast, native clipboard manager that lives in your Mac's menu bar.**

Remembers everything you copy — text *and* images — so you never lose a clip again.

No Electron. No dependencies. Just a tiny native Swift app.

![macOS](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Built%20with-Swift-F05138?logo=swift&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-blue)

</div>

---

## ✨ What it does

- 🗂️ **Clipboard history** — automatically saves everything you copy
- 🖼️ **Images too** — screenshots and copied pictures are kept as thumbnails
- 🔍 **Instant search** — type to filter your whole history
- 📌 **Pin favourites** — keep important clips from being cleared
- ⌨️ **Snippets** — store 9 reusable texts, paste with `⌘1`–`⌘9`
- 🎨 **Light / Dark / System** — clean, tactile design either way
- 🚀 **Launch at login** — always ready, stays out of your way
- 🔒 **100% local** — your clips never leave your Mac

---

## ⬇️ Download (easiest)

1. Go to the **[Releases page](../../releases/latest)** and download **`ClipVault.zip`**.
2. Double-click to unzip, then drag **ClipVault** into your **Applications** folder.
3. **Right-click** the app → **Open** → **Open** again.

> ℹ️ **Why right-click the first time?** ClipVault isn't signed with a paid
> Apple Developer certificate, so macOS asks you to confirm on first launch.
> After that, it opens normally. If macOS still blocks it, run this once in
> Terminal:
> ```bash
> xattr -dr com.apple.quarantine /Applications/ClipVault.app
> ```

That's it! Look for the clipboard icon in your menu bar.

---

## 🎹 How to use it

| Action | Shortcut |
|---|---|
| Open / close ClipVault | **`⌃⇧V`** (Control + Shift + V) |
| Paste a snippet | **`⌘1`** – **`⌘9`** |
| Copy a clip | Click it |
| Pin / delete a clip | Hover over it |
| Search | Just start typing |
| Settings | Gear icon in the popup |

> `⌃⇧V` is used on purpose so the system's **Paste and Match Style** (`⌘⇧V`)
> still works everywhere.

---

## 🛠️ Build it yourself

You only need Apple's **Command Line Tools** (`xcode-select --install`) — no Xcode required.

```bash
git clone https://github.com/benjaminhealey-netizen/clipvault.git
cd clipvault
bash build.sh
open ClipVault.app
```

`build.sh` compiles the Swift sources straight into `ClipVault.app`.

---

## 🧩 How it's built

A small, dependency-free native app:

| File | Role |
|---|---|
| `main.swift` | App entry point (menu-bar accessory) |
| `AppDelegate.swift` | Menu bar icon, popup, global hotkeys |
| `PopupView.swift` | The clipboard popup (SwiftUI) |
| `SettingsView.swift` | Settings window (SwiftUI) |
| `AppState.swift` | App logic & state |
| `ClipboardMonitor.swift` | Watches the clipboard |
| `DatabaseManager.swift` | Local SQLite storage |
| `Skeuomorphism.swift` | The tactile design system |
| `Models.swift` | Data types |

Built with **Swift + AppKit + SwiftUI**, storing history in **SQLite** (via the
system library — no third-party packages).

---

## 📄 License

[MIT](LICENSE) — free to use, modify, and share.

<div align="center">
<sub>Made with Swift on macOS 🖥️</sub>
</div>
