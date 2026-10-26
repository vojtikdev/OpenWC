import Foundation
import SwiftUI

struct MemberProfile: Codable {
    var user_id: UUID
    var display_name: String
    var bio: String
    var avatar_symbol: String
    var accent: String
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
    var needsRecheck: Bool { broken_count > 0 || last_report != nil }
    var title: String {
        if total == 0 { return last_report == nil ? "Not checked yet" : "Needs a recheck" }
        if broken_count > working_count { return "Reported issues" }
        if broken_count > 0 { return "Mixed reports" }
        return "Reported working"
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
