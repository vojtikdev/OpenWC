import SwiftUI
import Charts
import UIKit

struct CommunityStatusView: View {
    @EnvironmentObject var store: AppStore
    let place: Place
    @State private var feedback: String?
    private var summary: CheckSummary? { store.summaries[place.id] }
    private var own: CodeCheck? { store.checks.first { $0.place_id == place.id } }
    private var shouldPrompt: Bool {
        guard summary?.needsRecheck == true, let reportDate = CommunityDate.parse(summary?.last_report) else { return false }
        return CommunityDate.parse(own?.observed_at).map { $0 < reportDate } ?? true
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(summary?.title ?? "Not checked yet", systemImage: summary?.needsRecheck == true ? "exclamationmark.bubble.fill" : "checkmark.bubble.fill")
                    .font(.headline).foregroundStyle(summary?.color ?? .secondary)
                Spacer()
            }
            if shouldPrompt {
                Text("Someone reported a problem. Did this code still work for you?").font(.callout.weight(.semibold))
            } else { Text("Does this code still work?").font(.callout.weight(.semibold)) }
            HStack(spacing: 12) {
                Button { Task { await vote(true) } } label: {
                    Label("Works · \(summary?.working_count ?? 0)", systemImage: own?.works == true ? "checkmark.circle.fill" : "hand.thumbsup")
                        .font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 10)
                }.buttonStyle(.bordered).tint(.green)
                Button { Task { await vote(false) } } label: {
                    Label("Broken · \(summary?.broken_count ?? 0)", systemImage: own?.works == false ? "xmark.circle.fill" : "hand.thumbsdown")
                        .font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 10)
                }.buttonStyle(.bordered).tint(.orange)
            }.disabled(store.demo || store.checking)
            if store.checking { ProgressView("Saving your check…").font(.caption) }
            if let date = CommunityDate.parse(summary?.last_checked) {
                Text("Last community check \(date, style: .relative) ago").font(.caption).foregroundStyle(.secondary)
            }
            if own != nil { Text("Your latest answer is saved. Answer again if the code changes.").font(.caption).foregroundStyle(.secondary) }
            if let feedback { Text(feedback).font(.caption).foregroundStyle(.secondary) }
            if let error = store.communityError { Text(error).font(.caption).foregroundStyle(.orange) }
            Text(store.demo ? "Demo codes are fictional; voting is disabled." : "Counts cover the last 30 days. One current check per account/place. Two working checks with a working majority clear the recheck flag. Community feedback does not guarantee access.")
                .font(.caption2).foregroundStyle(.secondary)
        }.padding(20).background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24))
    }
    private func vote(_ works: Bool) async {
        feedback = nil
        do {
            if works { try await store.castCheck(place, works: true); feedback = "Thanks — your working-code check is saved." }
            else { await store.report(place); return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch { feedback = error.localizedDescription }
    }
}

struct ProfilePage: View {
    @EnvironmentObject var store: AppStore
    @State private var editing = false
    @State private var selected: Place?
    private var mine: [Place] { store.places.filter { $0.user_id == store.user?.id } }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: store.profile?.avatar_symbol ?? "person.fill")
                            .font(.system(size: 36)).foregroundStyle(.white)
                            .frame(width: 84, height: 84)
                            .background((store.profile?.color ?? violet).gradient, in: Circle())
                        Text(store.demo ? "Demo explorer" : store.profile?.display_name ?? "OpenWC explorer")
                            .font(.title2.bold())
                        if let bio = store.profile?.bio, !bio.isEmpty { Text(bio).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center) }
                        Text(store.user?.email ?? "Fictional demo account").font(.caption).foregroundStyle(.secondary)
                        Button("Edit profile") { editing = true }.buttonStyle(.bordered).disabled(store.demo)
                    }.frame(maxWidth: .infinity).padding(.vertical, 16)
                }
                Section("Your impact") {
                    HStack {
                        Metric(value: mine.count, title: "Places shared", symbol: "mappin.and.ellipse")
                        Metric(value: store.checks.count, title: "Codes checked", symbol: "checkmark.bubble")
                        Metric(value: store.savedIDs.count, title: "Saved places", symbol: "bookmark")
                    }
                    NavigationLink("Data & community overview") { AnalyticsView() }
                }
                Section("Saved for later") {
                    let saved = store.places.filter { store.savedIDs.contains($0.id) }
                    if saved.isEmpty { Text("Tap the bookmark on any place to save it.").foregroundStyle(.secondary) }
                    ForEach(saved) { place in
                        Button { selected = place } label: { PlaceRow(place: place, origin: nil) }.buttonStyle(.plain)
                    }
                }
                Section("Your contributions") {
                    if mine.isEmpty { Text("Your shared places will appear here.").foregroundStyle(.secondary) }
                    ForEach(mine) { place in
                        Button { selected = place } label: { PlaceRow(place: place, origin: nil) }.buttonStyle(.plain)
                    }
                }
                if let error = store.communityError { Section { Text(error).font(.caption).foregroundStyle(.orange) } }
                Section { Button(store.demo ? "Exit demo" : "Log out", role: .destructive) { Task { await store.signOut() } } }
            }
            .safeAreaPadding(.bottom, 20)
            .navigationTitle("Your corner.")
            .refreshable { await store.load() }
            .alert("OpenWC", isPresented: Binding(get: { store.message != nil && selected == nil }, set: { if !$0 { store.message = nil } })) {
                Button("OK") { store.message = nil }
            } message: { Text(store.message ?? "") }
            .sheet(isPresented: $editing) {
                if let id = store.user?.id { EditProfileView(profile: store.profile ?? .empty(userID: id)) }
            }
            .sheet(item: $selected) { PlaceDetail(place: $0, origin: nil) }
        }
    }
}

struct Metric: View {
    let value: Int
    let title: String
    let symbol: String
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).foregroundStyle(violet)
            Text(value, format: .number).font(.title2.bold())
            Text(title).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 10)
    }
}

struct EditProfileView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State var profile: MemberProfile
    @State private var saving = false
    @State private var error: String?
    private let symbols = ["person.fill", "leaf.fill", "sparkles", "cup.and.saucer.fill", "heart.fill", "figure.walk"]
    var body: some View {
        NavigationStack {
            Form {
                Section("Your identity") {
                    TextField("Display name", text: $profile.display_name)
                    TextField("A little about you (optional)", text: $profile.bio, axis: .vertical).lineLimit(2...4)
                    Text("\(profile.display_name.count)/40 name · \(profile.bio.count)/160 bio").font(.caption).foregroundStyle(.secondary)
                }
                Section("Avatar") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                        ForEach(symbols, id: \.self) { symbol in
                            Button { profile.avatar_symbol = symbol } label: {
                                Image(systemName: symbol).font(.title2).frame(width: 58, height: 58)
                                    .foregroundStyle(profile.avatar_symbol == symbol ? .white : profile.color)
                                    .background(profile.avatar_symbol == symbol ? profile.color : profile.color.opacity(0.12), in: Circle())
                            }.buttonStyle(.plain).accessibilityLabel(symbol.replacingOccurrences(of: ".fill", with: ""))
                        }
                    }.padding(.vertical, 8)
                    Picker("Accent", selection: $profile.accent) {
                        Text("Purple").tag("violet"); Text("Blue").tag("blue"); Text("Mint").tag("mint"); Text("Orange").tag("orange")
                    }
                }
                Section { Text("Your profile preferences are private to your account. They do not change your login email.").font(.caption).foregroundStyle(.secondary) }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle("Edit profile").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(saving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save") { Task { await save() } }
                        .disabled(saving || profile.display_name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || profile.display_name.count > 40 || profile.bio.count > 160)
                }
            }.interactiveDismissDisabled(saving)
        }
    }
    private func save() async {
        saving = true; error = nil
        defer { saving = false }
        do {
            profile.display_name = profile.display_name.trimmingCharacters(in: .whitespacesAndNewlines)
            try await store.saveProfile(profile); dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct AnalyticsView: View {
    @EnvironmentObject var store: AppStore
    private var mine: [Place] { store.places.filter { $0.user_id == store.user?.id } }
    private var working: Int { store.summaries.values.reduce(0) { $0 + $1.working_count } }
    private var broken: Int { store.summaries.values.reduce(0) { $0 + $1.broken_count } }
    private var days: [Date] { (0..<7).reversed().compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: Calendar.current.startOfDay(for: Date())) } }
    var body: some View {
        List {
            Section("Your contribution snapshot") {
                LabeledContent("Places shared", value: "\(mine.count)")
                LabeledContent("Step-free places shared", value: "\(mine.filter(\.accessible).count)")
                LabeledContent("Current code checks", value: "\(store.checks.count)")
                LabeledContent("Currently marked working by you", value: "\(store.checks.filter(\.works).count)")
                LabeledContent("Saved places", value: "\(store.savedIDs.count)")
            }
            Section("Your latest checks · last 7 days") {
                Chart(days, id: \.self) { date in
                    BarMark(x: .value("Day", date, unit: .day), y: .value("Checks", store.checks.filter { check in
                        CommunityDate.parse(check.observed_at).map { Calendar.current.isDate($0, inSameDayAs: date) } ?? false
                    }.count)).foregroundStyle(violet.gradient).cornerRadius(5)
                }.frame(height: 160).chartYAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
                Text("Each place contributes only its latest check. This is not a log of visits or every vote change.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Community · recent checks") {
                LabeledContent("Working reports", value: "\(working)")
                LabeledContent("Broken reports", value: "\(broken)")
                LabeledContent("Places needing a recheck", value: "\(store.summaries.values.filter(\.needsRecheck).count)")
                if working + broken > 0 {
                    ProgressView(value: Double(working), total: Double(working + broken))
                        .tint(.green).accessibilityLabel("Proportion of recent checks reporting working codes")
                }
                Text("Based on the places currently loaded and checks from the past 30 days. No location history or third-party analytics is collected for this overview.").font(.caption).foregroundStyle(.secondary)
            }
            if let error = store.communityError { Section { Text(error).foregroundStyle(.orange) } }
        }
        .safeAreaPadding(.bottom, 20)
        .navigationTitle("Your impact").navigationBarTitleDisplayMode(.inline)
        .refreshable { await store.loadCommunity() }
    }
}
