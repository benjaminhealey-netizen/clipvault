import Foundation
import SwiftUI

struct Clip: Identifiable, Equatable, Sendable {
    let id: Int64
    let content: String
    let type: ClipType
    let createdAt: Date
    let lastUsed: Date
    let useCount: Int
    var isPinned: Bool
    var imageData: Data?

    var preview: String {
        if type == .image {
            return imageData.map { "Image · \(byteString($0.count))" } ?? "Image"
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines).joined(separator: " ")
    }

    private func byteString(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        let kb = Double(bytes) / 1024
        if kb < 1024 { return String(format: "%.0f KB", kb) }
        return String(format: "%.1f MB", kb / 1024)
    }

    var timeAgo: String {
        let s = -lastUsed.timeIntervalSinceNow
        if s < 60 { return "just now" }
        if s < 3600 { return "\(Int(s/60))m ago" }
        if s < 86400 { return "\(Int(s/3600))h ago" }
        return "\(Int(s/86400))d ago"
    }
}

enum ClipType: String, CaseIterable, Sendable {
    case url, email, code, image, text

    static func detect(_ s: String) -> ClipType {
        let t = s.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("http://") || t.hasPrefix("https://") { return .url }
        let noSpace = !t.contains(" ")
        if noSpace, let at = t.firstIndex(of: "@") {
            let domain = t[t.index(after: at)...]
            if domain.contains(".") { return .email }
        }
        let codeChars = CharacterSet(charactersIn: "{[<(=>;|\\")
        if s.components(separatedBy: "\n").count > 2,
           s.unicodeScalars.contains(where: { codeChars.contains($0) }) { return .code }
        return .text
    }

    var badgeColor: Color {
        switch self {
        case .url:   return .blue
        case .email: return .green
        case .code:  return .purple
        case .image: return .orange
        case .text:  return Color(NSColor.tertiaryLabelColor)
        }
    }

    var label: String {
        switch self {
        case .url:   return "URL"
        case .email: return "EMAIL"
        case .code:  return "CODE"
        case .image: return "IMAGE"
        case .text:  return "TEXT"
        }
    }

    var icon: String {
        switch self {
        case .url:   return "link"
        case .email: return "envelope"
        case .code:  return "chevron.left.forwardslash.chevron.right"
        case .image: return "photo"
        case .text:  return "text.alignleft"
        }
    }
}

struct Snippet: Identifiable, Sendable {
    let slot: Int          // 1–9
    var name: String
    var content: String
    var id: Int { slot }
}
