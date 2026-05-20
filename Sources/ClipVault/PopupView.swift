import SwiftUI
import AppKit

// MARK: - Type Badge

struct TypeBadge: View {
    let type: ClipType

    var body: some View {
        Text(type.label)
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(type.badgeColor.opacity(0.18))
            .foregroundColor(type.badgeColor)
            .clipShape(Capsule())
    }
}

// MARK: - Clip Row

struct ClipRowView: View {
    let clip: Clip
    @ObservedObject var state: AppState
    @State private var isHovered = false
    @State private var deleteHovered = false

    var body: some View {
        HStack(spacing: 8) {
            // Pin indicator
            if clip.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.yellow)
            }

            // Main content
            VStack(alignment: .leading, spacing: 2) {
                Text(clip.preview)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: 6) {
                    TypeBadge(type: clip.type)
                    Text(clip.timeAgo)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    if clip.useCount > 1 {
                        Text("×\(clip.useCount)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Action buttons (shown on hover)
            if isHovered {
                HStack(spacing: 4) {
                    // Pin button
                    Button(action: { state.togglePin(clip) }) {
                        Image(systemName: clip.isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 12))
                            .foregroundColor(clip.isPinned ? .yellow : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(clip.isPinned ? "Unpin" : "Pin")

                    // Delete button
                    Button(action: { state.deleteClip(clip) }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(deleteHovered ? .red : .secondary)
                    }
                    .buttonStyle(.plain)
                    .onHover { deleteHovered = $0 }
                    .help("Delete")
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color(NSColor.selectedContentBackgroundColor).opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture {
            state.copyAndClose(clip)
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let isSearching: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: isSearching ? "magnifyingglass" : "doc.on.clipboard")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundColor(.secondary)
            Text(isSearching ? "No results found" : "Nothing copied yet")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            if !isSearching {
                Text("Copy something to get started")
                    .font(.system(size: 12))
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Main Popup View

struct PopupView: View {
    @ObservedObject var state: AppState
    @State private var localSearch: String = ""
    @State private var showClearConfirm = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Search
            searchBar

            Divider()
                .padding(.horizontal, 12)

            // Clip list
            if state.clips.isEmpty {
                EmptyStateView(isSearching: !localSearch.isEmpty)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(state.clips) { clip in
                            ClipRowView(clip: clip, state: state)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 4)
                }
            }

            Divider()

            // Footer
            footerView
        }
        .background(.regularMaterial)
        .frame(width: 380)
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
        HStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            Text("ClipVault")
                .font(.system(size: 14, weight: .semibold))
            Spacer()

            // Clear history button
            Button(action: { showClearConfirm = true }) {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Clear history")
            .confirmationDialog("Clear clipboard history?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Clear History", role: .destructive) {
                    state.clearHistory()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Pinned items will be kept.")
            }

            // Settings button
            Button(action: {
                NotificationCenter.default.post(name: .openSettings, object: nil)
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings (⌘,)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 13))
            TextField("Search clips...", text: $localSearch)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($searchFocused)
                .onKeyPress(.escape) {
                    if !localSearch.isEmpty {
                        localSearch = ""
                        return .handled
                    }
                    state.popoverRef?.performClose(nil)
                    return .handled
                }
                .onKeyPress(.return) {
                    if let first = state.clips.first {
                        state.copyAndClose(first)
                    }
                    return .handled
                }

            if !localSearch.isEmpty {
                Button(action: { localSearch = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private var footerView: some View {
        HStack {
            Text("\(state.clips.count) clip\(state.clips.count == 1 ? "" : "s")")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
            Text("⌘1–9 snippets")
                .font(.system(size: 11))
                .foregroundColor(Color(NSColor.tertiaryLabelColor))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openSettings = Notification.Name("com.clipvault.openSettings")
}
