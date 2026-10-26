import SwiftUI
import Supabase

enum LegalDocument: String, CaseIterable, Identifiable {
    case terms = "TERMS_OF_SERVICE"
    case privacy = "PRIVACY_POLICY"
    case copyright = "COPYRIGHT"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .terms: return "Terms of Service"
        case .privacy: return "Privacy Policy"
        case .copyright: return "Copyright & notices"
        }
    }
    var text: String {
        guard let url = Bundle.main.url(forResource: rawValue, withExtension: "md"),
              let value = try? String(contentsOf: url, encoding: .utf8) else {
            return "This document could not be loaded. Please try again after reinstalling the app."
        }
        return value
    }
}

struct LegalDocumentContent: View {
    let document: LegalDocument
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(Array(document.text.components(separatedBy: "\n\n").enumerated()), id: \.offset) { _, paragraph in
                    if paragraph.hasPrefix("# ") {
                        Text(String(paragraph.dropFirst(2))).font(.largeTitle.bold())
                    } else if paragraph.hasPrefix("## ") {
                        Text(String(paragraph.dropFirst(3))).font(.title3.bold()).padding(.top, 8)
                    } else {
                        Text(.init(paragraph)).font(.body).textSelection(.enabled)
                    }
                }
            }.frame(maxWidth: 680, alignment: .leading).padding(24).frame(maxWidth: .infinity)
        }.navigationTitle(document.title).navigationBarTitleDisplayMode(.inline)
    }
}

struct LegalDocumentView: View {
    @Environment(\.dismiss) private var dismiss
    let document: LegalDocument
    var body: some View {
        NavigationStack {
            LegalDocumentContent(document: document)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct AccountRequest: Decodable, Identifiable {
    let id: UUID
    let kind: String
    let message: String
    let status: String
}

struct PrivacyRequestView: View {
    @EnvironmentObject var store: AppStore
    @State private var kind = "access"
    @State private var details = ""
    @State private var sending = false
    @State private var confirmDeletion = false
    @State private var feedback: String?
    @State private var history: [AccountRequest] = []
    var body: some View {
        Form {
            Section {
                Text("Requests go privately to the OpenWC operator, Vojtěch Klepáček. They are processed manually. A deletion request does not immediately delete your account.")
                Text("The service is in development. A public support/privacy contact must be added before launch.").font(.caption).foregroundStyle(.secondary)
            }
            Section("New request") {
                Picker("Request", selection: $kind) {
                    Text("Access my data").tag("access")
                    Text("Correct my data").tag("correction")
                    Text("Delete my account and data").tag("deletion")
                    Text("Other privacy / copyright concern").tag("other")
                }
                TextField("Optional details (no passwords or sensitive documents)", text: $details, axis: .vertical).lineLimit(3...6)
                Button {
                    if kind == "deletion" { confirmDeletion = true }
                    else { Task { await send() } }
                } label: {
                    HStack { Text(sending ? "Submitting…" : "Submit request"); Spacer(); if sending { ProgressView() } }
                }.disabled(sending || store.demo || store.user == nil || details.count > 2000)
                if store.demo { Text("Log in to submit a real request.").foregroundStyle(.secondary) }
            }
            if let feedback { Section { Text(feedback).foregroundStyle(.secondary) } }
            Section("Your requests") {
                if history.isEmpty { Text("No requests yet.").foregroundStyle(.secondary) }
                ForEach(history) { item in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.kind.capitalized).font(.headline)
                        Text(item.status.capitalized).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Privacy & account")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Request deletion of your account, shared places and photos?", isPresented: $confirmDeletion, titleVisibility: .visible) {
            Button("Submit deletion request", role: .destructive) { Task { await send() } }
            Button("Cancel", role: .cancel) { }
        } message: { Text("This sends a private request for manual processing. Your account will remain active until it is processed. You can check the request status here.") }
        .task { await refresh() }
    }
    private func refresh() async {
        guard !store.demo, store.user != nil, let client = Backend.client else { return }
        do { history = try await client.from("account_requests").select().order("created_at", ascending: false).execute().value }
        catch { feedback = error.localizedDescription }
    }
    private func send() async {
        guard let user = store.user, !store.demo, let client = Backend.client else { return }
        sending = true; feedback = nil
        defer { sending = false }
        struct Request: Encodable { let user_id: UUID; let kind: String; let message: String }
        do {
            try await client.from("account_requests").insert(Request(user_id: user.id, kind: kind, message: details.trimmingCharacters(in: .whitespacesAndNewlines))).execute()
            details = ""
            feedback = "Request saved. It is pending manual review by the operator. Your account has not been deleted."
            await refresh()
        } catch { feedback = error.localizedDescription }
    }
}
