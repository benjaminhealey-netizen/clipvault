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

    var preview: String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines).joined(separator: " ")
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
    case url, email, code, text

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
        case .text:  return Color(NSColor.tertiaryLabelColor)
        }
    }

    var label: String {
        switch self {
        case .url:   return "URL"
        case .email: return "EMAIL"
        case .code:  return "CODE"
        case .text:  return "TEXT"
        }
    }
}

struct Snippet: Identifiable, Sendable {
    let slot: Int          // 1–9
    var name: String
    var content: String
    var id: Int { slot }
}
