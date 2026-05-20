import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var state: AppState
    @State private var historyLimit: String = "500"
    @State private var launchAtLogin: Bool = false
    @State private var theme: String = "system"
    @State private var snippetNames: [Int: String] = [:]
    @State private var snippetContents: [Int: String] = [:]
    @State private var saveIndicator: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("ClipVault Settings")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                if saveIndicator {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // MARK: General Section
                    sectionHeader("General")

                    VStack(spacing: 12) {
                        HStack {
                            Text("History limit")
                                .frame(width: 130, alignment: .leading)
                            Picker("", selection: $historyLimit) {
                                Text("100").tag("100")
                                Text("250").tag("250")
                                Text("500").tag("500")
                                Text("1000").tag("1000")
                                Text("Unlimited").tag("0")
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(width: 120)
                            Spacer()
                        }

                        HStack {
                            Text("Theme")
                                .frame(width: 130, alignment: .leading)
                            Picker("", selection: $theme) {
                                Text("System").tag("system")
                                Text("Light").tag("light")
                                Text("Dark").tag("dark")
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(width: 120)
                            Spacer()
                        }

                        HStack {
                            Text("Launch at login")
                                .frame(width: 130, alignment: .leading)
                            Toggle("", isOn: $launchAtLogin)
                                .labelsHidden()
                                .toggleStyle(.switch)
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    Divider().padding(.horizontal, 20)

                    // MARK: Snippets Section
                    sectionHeader("Snippets (⌘1–9)")

                    VStack(spacing: 8) {
                        ForEach(1...9, id: \.self) { slot in
                            HStack(spacing: 10) {
                                // Slot badge
                                Text("⌘\(slot)")
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .frame(width: 32, height: 22)
                                    .background(Color(NSColor.controlColor))
                                    .cornerRadius(5)
                                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(NSColor.separatorColor), lineWidth: 0.5))

                                TextField("Name", text: Binding(
                                    get: { snippetNames[slot] ?? "" },
                                    set: { snippetNames[slot] = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)

                                TextField("Content", text: Binding(
                                    get: { snippetContents[slot] ?? "" },
                                    set: { snippetContents[slot] = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    Divider().padding(.horizontal, 20)

                    // MARK: About Section
                    sectionHeader("About")

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "doc.on.clipboard.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("ClipVault")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Version 1.0.0")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        Text("Native macOS clipboard manager built with Swift.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }

            Divider()

            // Bottom buttons
            HStack {
                Button("Clear All History") {
                    state.clearHistory()
                    flashSaved()
                }
                .foregroundColor(.red)
                .buttonStyle(.plain)

                Spacer()

                Button("Save") {
                    saveSettings()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 480, height: 600)
        .onAppear {
            loadSettings()
        }
        .preferredColorScheme(colorScheme)
    }

    private var colorScheme: ColorScheme? {
        switch theme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)
    }

    private func loadSettings() {
        historyLimit = state.db.getSetting("historyLimit") ?? "500"
        theme = state.db.getSetting("theme") ?? "system"
        launchAtLogin = (state.db.getSetting("launchAtLogin") ?? "false") == "true"

        for s in state.snippets {
            snippetNames[s.slot] = s.name
            snippetContents[s.slot] = s.content
        }
        for slot in 1...9 {
            if snippetNames[slot] == nil { snippetNames[slot] = "Snippet \(slot)" }
            if snippetContents[slot] == nil { snippetContents[slot] = "" }
        }
    }

    private func saveSettings() {
        state.db.setSetting("historyLimit", value: historyLimit)
        state.db.setSetting("theme", value: theme)
        state.db.setSetting("launchAtLogin", value: launchAtLogin ? "true" : "false")

        for slot in 1...9 {
            let name = snippetNames[slot] ?? "Snippet \(slot)"
            let content = snippetContents[slot] ?? ""
            state.db.saveSnippet(slot: slot, name: name, content: content)
        }
        state.loadSnippets()
        flashSaved()
    }

    private func flashSaved() {
        withAnimation { saveIndicator = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { saveIndicator = false }
        }
    }
}
