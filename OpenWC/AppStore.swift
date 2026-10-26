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
    @Published var browseArea: BrowseArea?
    @Published var ownPlaces: [Place] = []
    @Published var savedPlaces: [Place] = []
    @Published var avatarURL: URL?
    @Published var demoAvatar: UIImage?
    @Published var areaHasMore = false
    private var loadToken = UUID()
    private var communityToken = UUID()
    private var authTask: Task<Void, Never>?
    init() {
        guard let client = Backend.client else { return }
        authTask = Task { [weak self] in
            for await (_, session) in client.auth.authStateChanges {
                guard let self else { return }
                let previousID = self.user?.id
                self.user = session?.user
                if previousID != self.user?.id { self.profile = nil; self.checks = []; self.summaries = [:]; self.savedIDs = []; self.avatarURL = nil; self.demoAvatar = nil; self.ownPlaces = []; self.savedPlaces = [] }
                if session != nil { self.demo = false; await self.load() }
                else if !self.demo { self.places = [] }
            }
        }
    }
    func preview() { demo = true; places = Place.samples; profile = nil; checks = []; summaries = [:]; savedIDs = []; savedPlaces = []; ownPlaces = []; avatarURL = nil; demoAvatar = nil; browseArea = .from(CLLocationCoordinate2D(latitude: 50.082, longitude: 14.424), name: "Prague · Demo") }
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
    func loadArea(_ area: BrowseArea) async {
        browseArea = area
        await load()
    }
    func load() async {
        guard !demo, let client = Backend.client, user != nil else { return }
        let token = UUID(); loadToken = token
        loading = true
        defer { if token == loadToken { loading = false } }
        do {
            let items: [Place]
            if let area = browseArea {
                struct Params: Encodable { let center_lat: Double; let center_lon: Double; let radius_m: Int; let max_results: Int }
                items = try await client.rpc("get_places_nearby", params: Params(center_lat: (area.latitude * 1000).rounded() / 1000, center_lon: (area.longitude * 1000).rounded() / 1000, radius_m: area.radius, max_results: 200)).execute().value
            } else {
                items = try await client.from("places").select().order("created_at", ascending: false).limit(200).execute().value
            }
            guard token == loadToken else { return }
            places = items; areaHasMore = items.count == 200
            await loadCommunity()
        } catch { if token == loadToken { message = error.localizedDescription } }
    }
    func signOut() async {
        if demo { demo = false; places = []; profile = nil; savedIDs = []; checks = []; summaries = [:]; avatarURL = nil; demoAvatar = nil; ownPlaces = []; savedPlaces = []; browseArea = nil; return }
        do {
            try await Backend.client?.auth.signOut()
            loadToken = UUID(); communityToken = UUID(); user = nil; places = []; profile = nil
            savedIDs = []; savedPlaces = []; ownPlaces = []; checks = []; summaries = [:]
            avatarURL = nil; demoAvatar = nil; browseArea = nil
        }
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
        guard !demo, let accountID = user?.id, let client = Backend.client else { return }
        let token = UUID(); communityToken = token
        let visiblePlaces = places
        communityError = nil
        do {
            let profiles: [MemberProfile] = try await client.from("profiles").select().execute().value
            let loadedProfile = profiles.first
            var loadedAvatar: URL?
            if let path = loadedProfile?.avatar_path {
                loadedAvatar = try? await client.storage.from("profile-photos").createSignedURL(path: path, expiresIn: 3600)
            }
            let mine: [Place] = try await client.from("places").select().eq("user_id", value: accountID).order("created_at", ascending: false).limit(200).execute().value
            let votes: [CodeCheck] = try await client.from("code_checks").select().execute().value
            let saved: [SavedPlace] = try await client.from("saved_places").select().execute().value
            let savedSet = Set(saved.map(\.place_id))
            let loadedSaved: [Place]
            if savedSet.isEmpty { loadedSaved = [] }
            else { loadedSaved = try await client.from("places").select().in("id", values: Array(savedSet.prefix(200))).execute().value }
            let ids = Array(Set((visiblePlaces + mine + loadedSaved).map(\.id)))
            var loadedSummaries: [UUID: CheckSummary] = [:]
            if !ids.isEmpty {
                struct Params: Encodable { let place_ids: [UUID] }
                let values: [CheckSummary] = try await client.rpc("get_code_check_summaries", params: Params(place_ids: ids)).execute().value
                loadedSummaries = Dictionary(uniqueKeysWithValues: values.map { ($0.place_id, $0) })
            }
            guard user?.id == accountID, !demo, token == communityToken else { return }
            profile = loadedProfile; avatarURL = loadedAvatar; ownPlaces = mine
            checks = votes; savedIDs = savedSet; savedPlaces = loadedSaved; summaries = loadedSummaries
        } catch {
            if user?.id == accountID, token == communityToken { communityError = "Community data couldn’t refresh. Pull to refresh or try again. " + error.localizedDescription }
        }
    }
    func saveProfile(_ value: MemberProfile, photo: Data? = nil, removePhoto: Bool = false) async throws {
        if demo {
            profile = value
            if let photo { demoAvatar = UIImage(data: photo) }
            else if removePhoto { demoAvatar = nil }
            return
        }
        guard let user, value.user_id == user.id, let client = Backend.client else { throw AppError.message("Log in to edit your profile.") }
        var updated = value
        let oldPath = profile?.avatar_path
        var newPath: String?
        if let photo {
            let path = "\(user.id.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"
            try await client.storage.from("profile-photos").upload(path, data: photo, options: FileOptions(contentType: "image/jpeg", upsert: false))
            newPath = path; updated.avatar_path = path
        } else if removePhoto { updated.avatar_path = nil }
        do { try await client.from("profiles").upsert(updated, onConflict: "user_id").execute() }
        catch {
            if let newPath { _ = try? await client.storage.from("profile-photos").remove(paths: [newPath]) }
            throw error
        }
        communityToken = UUID()
        profile = updated
        avatarURL = nil
        if let path = updated.avatar_path { avatarURL = try? await client.storage.from("profile-photos").createSignedURL(path: path, expiresIn: 3600) }
        if let oldPath, oldPath != updated.avatar_path { _ = try? await client.storage.from("profile-photos").remove(paths: [oldPath]) }
    }
    func toggleSaved(_ place: Place) async throws {
        if demo {
            if savedIDs.contains(place.id) { savedIDs.remove(place.id); savedPlaces.removeAll { $0.id == place.id } }
            else { savedIDs.insert(place.id); savedPlaces.append(place) }
            return
        }
        guard let user, let client = Backend.client else { throw AppError.message("Log in to save places.") }
        if savedIDs.contains(place.id) {
            try await client.from("saved_places").delete().eq("user_id", value: user.id).eq("place_id", value: place.id).execute()
            communityToken = UUID()
            savedIDs.remove(place.id)
            savedPlaces.removeAll { $0.id == place.id }
        } else {
            try await client.from("saved_places").insert(SavedPlace(user_id: user.id, place_id: place.id)).execute()
            communityToken = UUID()
            savedIDs.insert(place.id)
            savedPlaces.append(place)
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
