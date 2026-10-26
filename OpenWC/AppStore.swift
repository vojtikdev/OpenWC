import SwiftUI
import Supabase
import MapKit
import UIKit

@MainActor
final class AppStore: ObservableObject {
    @Published var user: User?
    @Published var places: [Place] = []
    @Published var demo = false
    @Published var loading = false
    @Published var message: String?
    @Published var profile: MemberProfile?
    @Published var checks: [CodeCheck] = []
    @Published var summaries: [UUID: CheckSummary] = [:]
    @Published var savedIDs: Set<UUID> = []
    @Published var communityError: String?
    @Published var checking = false
    private var authTask: Task<Void, Never>?
    init() {
        guard let client = Backend.client else { return }
        authTask = Task { [weak self] in
            for await (_, session) in client.auth.authStateChanges {
                guard let self else { return }
                let previousID = self.user?.id
                self.user = session?.user
                if previousID != self.user?.id { self.profile = nil; self.checks = []; self.summaries = [:]; self.savedIDs = [] }
                if session != nil { self.demo = false; await self.load() }
                else if !self.demo { self.places = [] }
            }
        }
    }
    func preview() { demo = true; places = Place.samples; profile = nil; checks = []; summaries = [:]; savedIDs = [] }
    func authenticate(email: String, password: String, register: Bool, acceptedTerms: Bool = false) async {
        guard let client = Backend.client else { message = "Connect your Supabase project using Config.xcconfig to enable accounts. You can explore the demo now."; return }
        guard !register || acceptedTerms else { message = "Read and accept the Terms of Service before registering."; return }
        message = nil
        loading = true
        defer { loading = false }
        do {
            if register {
                let result = try await client.auth.signUp(email: email, password: password, data: [
                    "terms_version": .string("2026-10-26"),
                    "terms_accepted_at": .string(ISO8601DateFormatter().string(from: Date()))
                ])
                if result.session == nil { message = "Check your email to confirm your account, then return here and log in." }
            } else { try await client.auth.signIn(email: email, password: password) }
        } catch { message = error.localizedDescription }
    }
    func load() async {
        guard !demo, let client = Backend.client, user != nil else { return }
        loading = true
        defer { loading = false }
        do {
            places = try await client.from("places").select().order("created_at", ascending: false).execute().value
            await loadCommunity()
        }
        catch { message = error.localizedDescription }
    }
    func signOut() async {
        if demo { demo = false; places = []; profile = nil; savedIDs = []; checks = []; summaries = [:]; return }
        do { try await Backend.client?.auth.signOut(); user = nil; places = [] }
        catch { message = error.localizedDescription }
    }
    func add(name: String, address: String, coordinate: CLLocationCoordinate2D, code: String, notes: String, accessible: Bool, photo: Data?) async throws {
        guard !demo, let user, let client = Backend.client else { throw AppError.message("Log in to share a real place. Demo mode cannot publish.") }
        let id = UUID()
        var path: String?
        if let photo {
            let value = "\(user.id.uuidString.lowercased())/\(id.uuidString.lowercased()).jpg"
            try await client.storage.from("place-photos").upload(value, data: photo, options: FileOptions(contentType: "image/jpeg", upsert: false))
            path = value
        }
        let place = Place(id: id, user_id: user.id, name: name, address: address, latitude: coordinate.latitude, longitude: coordinate.longitude, code: code, notes: notes, accessible: accessible, photo_path: path)
        do {
            try await client.from("places").insert(place).execute()
            await load()
        } catch {
            if let path { _ = try? await client.storage.from("place-photos").remove(paths: [path]) }
            throw error
        }
    }
    func loadCommunity() async {
        guard !demo, user != nil, let client = Backend.client else { return }
        communityError = nil
        do {
            let profiles: [MemberProfile] = try await client.from("profiles").select().execute().value
            profile = profiles.first
            checks = try await client.from("code_checks").select().execute().value
            let saved: [SavedPlace] = try await client.from("saved_places").select().execute().value
            savedIDs = Set(saved.map(\.place_id))
            if places.isEmpty { summaries = [:] }
            else {
                struct Params: Encodable { let place_ids: [UUID] }
                let items: [CheckSummary] = try await client.rpc("get_code_check_summaries", params: Params(place_ids: places.map(\.id))).execute().value
                summaries = Dictionary(uniqueKeysWithValues: items.map { ($0.place_id, $0) })
            }
        } catch { communityError = "Community data couldn’t refresh. Pull to refresh or try again. " + error.localizedDescription }
    }
    func saveProfile(_ value: MemberProfile) async throws {
        guard !demo, let user, value.user_id == user.id, let client = Backend.client else { throw AppError.message("Log in to edit your profile.") }
        try await client.from("profiles").upsert(value, onConflict: "user_id").execute()
        profile = value
    }
    func toggleSaved(_ place: Place) async throws {
        if demo {
            if savedIDs.contains(place.id) { savedIDs.remove(place.id) } else { savedIDs.insert(place.id) }
            return
        }
        guard let user, let client = Backend.client else { throw AppError.message("Log in to save places.") }
        if savedIDs.contains(place.id) {
            try await client.from("saved_places").delete().eq("user_id", value: user.id).eq("place_id", value: place.id).execute()
            savedIDs.remove(place.id)
        } else {
            try await client.from("saved_places").insert(SavedPlace(user_id: user.id, place_id: place.id)).execute()
            savedIDs.insert(place.id)
        }
    }
    func castCheck(_ place: Place, works: Bool) async throws {
        guard !demo, let user, let client = Backend.client else { throw AppError.message("Log in to check a real code. Demo codes are fictional.") }
        guard !checking else { return }
        checking = true
        defer { checking = false }
        struct Vote: Encodable { let place_id: UUID; let user_id: UUID; let works: Bool }
        struct CheckUpdate: Encodable { let works: Bool }
        let updated: [CodeCheck] = try await client.from("code_checks").update(CheckUpdate(works: works))
            .eq("place_id", value: place.id).eq("user_id", value: user.id).select().execute().value
        if updated.isEmpty {
            do {
                try await client.from("code_checks").insert(Vote(place_id: place.id, user_id: user.id, works: works)).execute()
            } catch {
                guard (error as? PostgrestError)?.code == "23505" else { throw error }
                try await client.from("code_checks").update(CheckUpdate(works: works))
                    .eq("place_id", value: place.id).eq("user_id", value: user.id).execute()
            }
        }
        await loadCommunity()
    }
    func report(_ place: Place) async {
        guard let client = Backend.client, let user, !demo else { message = "Reporting is available when logged in."; return }
        struct Report: Encodable { let place_id: UUID; let user_id: UUID; let reason: String }
        do {
            try await castCheck(place, works: false)
            do {
                try await client.from("reports").insert(Report(place_id: place.id, user_id: user.id, reason: "Code no longer works")).execute()
            } catch {
                if (error as? PostgrestError)?.code != "23505" { throw error }
            }
            await loadCommunity()
            message = "Your broken-code check was saved. Other visitors can confirm or disagree on this place’s page."
        } catch { message = error.localizedDescription }
    }
    func photoURL(_ path: String) -> URL? { try? Backend.client?.storage.from("place-photos").getPublicURL(path: path) }
}

enum AppError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(text) = self { return text }; return nil }
}
