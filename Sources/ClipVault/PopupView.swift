import SwiftUI
import AppKit

// MARK: - Type Badge

struct TypeBadge: View {
    let type: ClipType

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: type.icon)
                .font(.system(size: 8, weight: .bold))
            Text(type.label)
                .font(.system(size: 9, weight: .bold))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(
            Capsule()
                .fill(type.badgeColor.opacity(0.16))
                .overlay(Capsule().strokeBorder(type.badgeColor.opacity(0.35), lineWidth: 0.5))
        )
        .foregroundColor(type.badgeColor)
    }
}

// MARK: - Leading tile (image thumbnail or type icon)

struct ClipTile: View {
    let clip: Clip
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
        Group {
            if clip.type == .image, let data = clip.imageData, let img = NSImage(data: data) {
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
            } else {
                let p = SkeuoPalette(scheme)
                Image(systemName: clip.type.icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(clip.type.badgeColor.opacity(0.9))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        LinearGradient(colors: [p.wellTop, p.wellBottom], startPoint: .top, endPoint: .bottom)
                    )
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(shape)
        .overlay(
            shape.strokeBorder(SkeuoPalette(scheme).stroke, lineWidth: 0.75)
        )
        .overlay(
            // glassy top sheen on the photo frame
            shape.strokeBorder(SkeuoPalette(scheme).topHighlight.opacity(0.5), lineWidth: 0.75)
                .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .center))
        )
        .shadow(color: .black.opacity(scheme == .dark ? 0.4 : 0.18), radius: 1.5, y: 1)
    }
}

// MARK: - Clip Row

struct ClipRowView: View {
    let clip: Clip
    @ObservedObject var state: AppState
    @Environment(\.colorScheme) private var scheme
    @State private var isHovered = false
    @State private var deleteHovered = false

    var body: some View {
        let p = SkeuoPalette(scheme)
        HStack(spacing: 10) {
            ClipTile(clip: clip)

            // Main content
            VStack(alignment: .leading, spacing: 3) {
                Text(clip.preview)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(p.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: 6) {
                    TypeBadge(type: clip.type)
                    Text(clip.timeAgo)
                        .font(.system(size: 11))
                        .foregroundColor(p.textSecondary)
                    if clip.useCount > 1 {
                        Text("×\(clip.useCount)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(p.textTertiary)
                    }
                }
            }

            Spacer(minLength: 4)

            if clip.isPinned && !isHovered {
                Image(systemName: "pin.fill")
                    .font(.system(size: 11))
                    .foregroundColor(p.accent)
                    .rotationEffect(.degrees(45))
            }

            // Action buttons (shown on hover)
            if isHovered {
                HStack(spacing: 6) {
                    Button(action: { state.togglePin(clip) }) {
                        Image(systemName: clip.isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 11))
                            .foregroundColor(clip.isPinned ? p.accent : p.textSecondary)
                            .rotationEffect(.degrees(45))
                    }
                    .buttonStyle(SkeuoIconButtonStyle(size: 24))
                    .help(clip.isPinned ? "Unpin" : "Pin")

                    Button(action: { state.deleteClip(clip) }) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 11))
                            .foregroundColor(deleteHovered ? .red : p.textSecondary)
                    }
                    .buttonStyle(SkeuoIconButtonStyle(size: 24))
                    .onHover { deleteHovered = $0 }
                    .help("Delete")
                }
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .skeuoCard(cornerRadius: 10, hovered: isHovered)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { state.copyAndClose(clip) }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let isSearching: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = SkeuoPalette(scheme)
        VStack(spacing: 14) {
            Image(systemName: isSearching ? "magnifyingglass" : "tray")
                .font(.system(size: 38, weight: .light))
                .foregroundColor(p.textTertiary)
                .skeuoEngraved(scheme)
            Text(isSearching ? "No results found" : "Nothing copied yet")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(p.textSecondary)
            if !isSearching {
                Text("Copy text or an image to get started")
                    .font(.system(size: 12))
                    .foregroundColor(p.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Main Popup View

struct PopupView: View {
    @ObservedObject var state: AppState
    @Environment(\.colorScheme) private var scheme
    @State private var localSearch: String = ""
    @State private var showClearConfirm = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            headerView
            searchBar

            if state.clips.isEmpty {
                EmptyStateView(isSearching: !localSearch.isEmpty)
            } else {
                ScrollView {
                    LazyVStack(spacing: 7) {
                        ForEach(state.clips) { clip in
                            ClipRowView(clip: clip, state: state)
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 10)
                }
            }

            footerView
        }
        .frame(width: 380)
        .skeuoWindow()
        .onAppear {
            localSearch = ""
            state.search("")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                searchFocused = true
            }
        }
        .onChange(of: localSearch) { _, newValue in
            state.search(newValue)
        }
    }

    private var headerView: some View {
        let p = SkeuoPalette(scheme)
        return HStack(spacing: 9) {
            // Brass emblem
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [p.accentTop, p.accentBottom], startPoint: .top, endPoint: .bottom)
                            .shadow(.inner(color: .white.opacity(0.5), radius: 0.5, y: 0.75))
                    )
                    .overlay(Circle().strokeBorder(p.accentBottom.opacity(0.7), lineWidth: 0.75))
                    .shadow(color: .black.opacity(0.3), radius: 1.5, y: 1)
                    .frame(width: 22, height: 22)
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(p.isDark ? Color(hex: 0x3A2A06) : .white)
            }

            Text("ClipVault")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(p.textPrimary)
                .skeuoEngraved(scheme)

            Spacer()

            Button(action: { showClearConfirm = true }) {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(p.textSecondary)
            }
            .buttonStyle(SkeuoIconButtonStyle())
            .help("Clear history")
            .confirmationDialog("Clear clipboard history?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Clear History", role: .destructive) { state.clearHistory() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Pinned items will be kept.")
            }

            Button(action: {
                NotificationCenter.default.post(name: .openSettings, object: nil)
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(p.textSecondary)
            }
            .buttonStyle(SkeuoIconButtonStyle())
            .help("Settings")
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var searchBar: some View {
        let p = SkeuoPalette(scheme)
        return HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(p.textSecondary)
                .font(.system(size: 13, weight: .medium))
            TextField("Search clips…", text: $localSearch)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(p.textPrimary)
                .focused($searchFocused)
                .onKeyPress(.escape) {
                    if !localSearch.isEmpty { localSearch = ""; return .handled }
                    state.popoverRef?.performClose(nil)
                    return .handled
                }
                .onKeyPress(.return) {
                    if let first = state.clips.first { state.copyAndClose(first) }
                    return .handled
                }

            if !localSearch.isEmpty {
                Button(action: { localSearch = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(p.textTertiary)
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .skeuoWell(cornerRadius: 9)
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    private var footerView: some View {
        let p = SkeuoPalette(scheme)
        return HStack {
            Text("\(state.clips.count) clip\(state.clips.count == 1 ? "" : "s")")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(p.textSecondary)
            Spacer()
            Text("⌃⇧V toggle · ⌘1–9 snippets")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(p.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            Rectangle()
                .fill(p.bgBottom.opacity(0.5))
                .overlay(
                    Rectangle().frame(height: 0.75).foregroundColor(p.stroke.opacity(0.6)),
                    alignment: .top
                )
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openSettings = Notification.Name("com.clipvault.openSettings")
}
