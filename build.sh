#!/bin/bash
set -e

SRCDIR="Sources/ClipVault"
APPDIR="ClipVault.app/Contents/MacOS"
SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"

echo "Building ClipVault..."

swiftc \
  -target arm64-apple-macosx14.0 \
  -sdk "$SDK" \
  -O \
  -framework AppKit \
  -framework SwiftUI \
  -lsqlite3 \
  "$SRCDIR/Models.swift" \
  "$SRCDIR/Skeuomorphism.swift" \
  "$SRCDIR/DatabaseManager.swift" \
  "$SRCDIR/ClipboardMonitor.swift" \
  "$SRCDIR/ScreenshotWatcher.swift" \
  "$SRCDIR/AppState.swift" \
  "$SRCDIR/PopupView.swift" \
  "$SRCDIR/SettingsView.swift" \
  "$SRCDIR/AppDelegate.swift" \
  "$SRCDIR/main.swift" \
  -o "$APPDIR/ClipVault"

echo "✓ Build succeeded → ClipVault.app"
