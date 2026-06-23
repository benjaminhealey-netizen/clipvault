import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var state: AppState
    @Environment(\.colorScheme) private var scheme
    @State private var historyLimit: String = "500"
    @State private var launchAtLogin: Bool = false
    @State private var theme: String = "system"
    @State private var snippetNames: [Int: String] = [:]
    @State private var snippetContents: [Int: String] = [:]
    @State private var saveIndicator: Bool = false

    var body: some View {
        let p = SkeuoPalette(scheme)
        VStack(spacing: 0) {
            // Title bar
            HStack(spacing: 9) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(colors: [p.accentTop, p.accentBottom], startPoint: .top, endPoint: .bottom)
                                .shadow(.inner(color: .white.opacity(0.5), radius: 0.5, y: 0.75))
                        )
                        .overlay(Circle().strokeBorder(p.accentBottom.opacity(0.7), lineWidth: 0.75))
                        .frame(width: 24, height: 24)
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
                Text("ClipVault Settings")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(p.textPrimary)
                    .skeuoEngraved(scheme)
                Spacer()
                if saveIndicator {
                    Label("Saved", systemImage: "checkmark.seal.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // MARK: General
                    settingsGroup("General") {
                        settingRow("History limit") {
                            Picker("", selection: $historyLimit) {
                                Text("100").tag("100")
                                Text("250").tag("250")
                                Text("500").tag("500")
                                Text("1000").tag("1000")
                                Text("Unlimited").tag("0")
                            }
                            .pickerStyle(.menu).labelsHidden().frame(width: 130)
                        }
                        Divider().opacity(0.4)
                        settingRow("Appearance") {
                            Picker("", selection: $theme) {
                                Text("System").tag("system")
                                Text("Light").tag("light")
                                Text("Dark").tag("dark")
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 200)
                            .onChange(of: theme) { _, newValue in
                                // Apply immediately so the popup updates too
                                state.setTheme(newValue)
                            }
                        }
                        Divider().opacity(0.4)
                        settingRow("Launch at login") {
                            Toggle("", isOn: $launchAtLogin).labelsHidden().toggleStyle(.switch)
                        }
                    }

                    // MARK: Snippets
                    settingsGroup("Snippets · ⌘1–9") {
                        ForEach(1...9, id: \.self) { slot in
                            if slot > 1 { Divider().opacity(0.4) }
                            HStack(spacing: 10) {
                                Text("⌘\(slot)")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(p.accent)
                                    .frame(width: 34, height: 24)
                                    .skeuoWell(cornerRadius: 6)

                                skeuoField("Name", width: 110, text: Binding(
                                    get: { snippetNames[slot] ?? "" },
                                    set: { snippetNames[slot] = $0 }
                                ))
                                skeuoField("Content", width: nil, text: Binding(
                                    get: { snippetContents[slot] ?? "" },
                                    set: { snippetContents[slot] = $0 }
                                ))
                            }
                        }
                    }

                    // MARK: About
                    settingsGroup("About") {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.on.clipboard.fill")
                                .font(.system(size: 26))
                                .foregroundColor(p.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("ClipVault")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(p.textPrimary)
                                Text("Version 1.0 · Native Swift")
                                    .font(.system(size: 12))
                                    .foregroundColor(p.textSecondary)
                            }
                            Spacer()
                        }
                        Text("A native macOS clipboard manager. No Electron, no dependencies — text and images, captured automatically.")
                            .font(.system(size: 12))
                            .foregroundColor(p.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }

            // Bottom bar
            HStack {
                Button(action: { state.clearHistory(); flashSaved() }) {
                    Label("Clear All History", systemImage: "trash")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                Spacer()
                Button("Save") { saveSettings() }
                    .buttonStyle(SkeuoProminentButtonStyle())
                    .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                Rectangle()
                    .fill(p.bgBottom.opacity(0.5))
                    .overlay(Rectangle().frame(height: 0.75).foregroundColor(p.stroke.opacity(0.6)), alignment: .top)
            )
        }
        .frame(width: 500, height: 620)
        .skeuoWindow()
        .onAppear { loadSettings() }
        .preferredColorScheme(colorScheme)
    }

    // MARK: - Reusable building blocks

    private func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        let p = SkeuoPalette(scheme)
        return VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(p.textTertiary)
                .skeuoEngraved(scheme)
                .padding(.leading, 4)
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .skeuoCard(cornerRadius: 12)
        }
    }

    private func settingRow<Control: View>(_ label: String, @ViewBuilder control: () -> Control) -> some View {
        let p = SkeuoPalette(scheme)
        return HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(p.textPrimary)
            Spacer()
            control()
        }
    }

    private func skeuoField(_ placeholder: String, width: CGFloat?, text: Binding<String>) -> some View {
        let p = SkeuoPalette(scheme)
        return TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .foregroundColor(p.textPrimary)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .frame(width: width)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .skeuoWell(cornerRadius: 6)
    }

    private var colorScheme: ColorScheme? {
        switch theme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    // MARK: - Persistence

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
