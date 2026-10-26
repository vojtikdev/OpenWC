import Foundation
import SwiftUI

struct MemberProfile: Codable {
    var user_id: UUID
    var display_name: String
    var bio: String
    var avatar_symbol: String
    var accent: String
    var avatar_path: String? = nil
    enum CodingKeys: String, CodingKey { case user_id, display_name, bio, avatar_symbol, accent, avatar_path }
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(user_id, forKey: .user_id)
        try values.encode(display_name, forKey: .display_name)
        try values.encode(bio, forKey: .bio)
        try values.encode(avatar_symbol, forKey: .avatar_symbol)
        try values.encode(accent, forKey: .accent)
        try values.encode(avatar_path, forKey: .avatar_path)
    }
    var color: Color {
        switch accent { case "blue": return .blue; case "mint": return .mint; case "orange": return .orange; default: return violet }
    }
    static func empty(userID: UUID) -> MemberProfile {
        .init(user_id: userID, display_name: "OpenWC explorer", bio: "", avatar_symbol: "person.fill", accent: "violet")
    }
}
struct CodeCheck: Codable {
    let place_id: UUID
    let user_id: UUID
    let works: Bool
    let observed_at: String
}
struct CheckSummary: Decodable {
    let place_id: UUID
    let working_count: Int
    let broken_count: Int
    let last_checked: String?
    let last_report: String?
    var total: Int { working_count + broken_count }
    var needsRecheck: Bool {
        if working_count >= 2 && working_count > broken_count { return false }
        return broken_count > 0 || last_report != nil
    }
    var title: String {
        if total == 0 { return last_report == nil ? "Not checked yet" : "Needs a recheck" }
        if working_count >= 2 && working_count > broken_count { return "Reported working" }
        if broken_count > working_count { return "Reported issues" }
        if broken_count > 0 { return "Mixed reports" }
        return needsRecheck ? "Needs a recheck" : "Reported working"
    }
    var color: Color { needsRecheck ? .orange : total > 0 ? .green : .secondary }
}
struct SavedPlace: Codable { let user_id: UUID; let place_id: UUID }
enum CommunityDate {
    static func parse(_ text: String?) -> Date? {
        guard let text else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }
}
