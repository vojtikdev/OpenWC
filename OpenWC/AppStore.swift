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
    private var authTask: Task<Void, Never>?
    init() {
        guard let client = Backend.client else { return }
        authTask = Task { [weak self] in
            for await (_, session) in client.auth.authStateChanges {
                guard let self else { return }
                self.user = session?.user
                if session != nil { self.demo = false; await self.load() }
                else if !self.demo { self.places = [] }
            }
        }
    }
    func preview() { demo = true; places = Place.samples }
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
        do { places = try await client.from("places").select().order("created_at", ascending: false).execute().value }
        catch { message = error.localizedDescription }
    }
    func signOut() async {
        if demo { demo = false; places = []; return }
        do { try await Backend.client?.auth.signOut(); user = nil; places = [] }
        catch { message = error.localizedDescription }
    }
    func add(name: String, address: String, coordinate: CLLocationCoordinate2D, code: String, notes: String, accessible: Bool, photo: Data?) async throws {
        guard !demo, let user, let client = Backend.client else { throw AppError.message("Log in to share a real place. Demo mode cannot publish.") }
        let id = UUID()
        var path: String?
        if let photo {
            let value = "\(user.id.uuidString.lowercased())/\(id.uuidString.lowercased()).jpg"
            try await client.storage.from("place-photos").upload(path: value, file: photo, options: FileOptions(contentType: "image/jpeg", upsert: false))
            path = value
        }
        let place = Place(id: id, user_id: user.id, name: name, address: address, latitude: coordinate.latitude, longitude: coordinate.longitude, code: code, notes: notes, accessible: accessible, photo_path: path)
        do {
            try await client.from("places").insert(place).execute()
            await load()
        } catch {
            if let path { try? await client.storage.from("place-photos").remove(paths: [path]) }
            throw error
        }
    }
    func report(_ place: Place) async {
        guard let client = Backend.client, let user, !demo else { message = "Reporting is available when logged in."; return }
        struct Report: Encodable { let place_id: UUID; let user_id: UUID; let reason: String }
        do {
            try await client.from("reports").insert(Report(place_id: place.id, user_id: user.id, reason: "Code no longer works")).execute()
            message = "Thanks. Your report has been saved for review."
        } catch { message = error.localizedDescription }
    }
    func photoURL(_ path: String) -> URL? { try? Backend.client?.storage.from("place-photos").getPublicURL(path: path) }
}

enum AppError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(text) = self { return text }; return nil }
}
