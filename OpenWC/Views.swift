import SwiftUI
import MapKit
import UIKit

let violet = Color(red: 0.66, green: 0.46, blue: 1)

struct RootView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        Group {
            if store.user != nil || store.demo { HomeView() }
            else { WelcomeView() }
        }
    }
}

struct WelcomeView: View {
    @EnvironmentObject var store: AppStore
    @State private var auth: Bool?
    @State private var legal: LegalDocument?
    var body: some View {
        ZStack {
            Map(initialPosition: .region(.init(center: .init(latitude: 50.082, longitude: 14.424), span: .init(latitudeDelta: 0.018, longitudeDelta: 0.018)))) {
                ForEach(Place.samples) { place in
                    Annotation(place.name, coordinate: place.coordinate) { Pin(name: place.name) }
                }
            }.mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
                .allowsHitTesting(false).ignoresSafeArea()
            LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.8), .black], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 22) {
                HStack { Image(systemName: "drop.circle.fill").font(.largeTitle).foregroundStyle(violet); Text("OpenWC").font(.title.bold()) }.foregroundStyle(.white)
                Spacer()
                Text("A little relief.\nA more open city.").font(.system(size: 46, weight: .bold, design: .rounded)).tracking(-2).foregroundStyle(.white)
                Text("Find a nearby toilet. Share a code.\nMake someone’s day a little easier.").foregroundStyle(.white.opacity(0.7)).font(.title3)
                VStack(spacing: 12) {
                    Button { auth = true } label: { Text("Create an account").frame(maxWidth: .infinity).padding(18).background(violet, in: Capsule()).foregroundStyle(.black).bold() }
                    Button { auth = false } label: { Text("I already have an account").frame(maxWidth: .infinity).padding(18).background(.ultraThinMaterial, in: Capsule()).foregroundStyle(.white) }
                    Button("Explore a demo") { store.preview() }.font(.subheadline).foregroundStyle(.white.opacity(0.7)).padding(8)
                }
                HStack {
                    Button("Terms") { legal = .terms }
                    Spacer()
                    Button("Privacy") { legal = .privacy }
                    Spacer()
                    Button("Copyright") { legal = .copyright }
                }.font(.caption).foregroundStyle(.white.opacity(0.8))
                Text("Built by people. Open to everyone.").font(.caption).foregroundStyle(.white.opacity(0.45)).frame(maxWidth: .infinity)
            }.padding(28).padding(.top, 20)
        }
        .sheet(isPresented: Binding(get: { auth != nil }, set: { if !$0 { auth = nil } })) { AuthView(register: auth ?? false) }
        .sheet(item: $legal) { LegalDocumentView(document: $0) }
    }
}

struct Pin: View {
    var name: String = ""
    var body: some View {
        VStack(spacing: -4) {
            BusinessBadge(name: name, size: 43)
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(.white.opacity(0.7), lineWidth: 2))
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
            Image(systemName: "arrowtriangle.down.fill").font(.system(size: 12)).foregroundStyle(violet)
        }
    }
}

struct PlaceRow: View {
    @EnvironmentObject var store: AppStore
    let place: Place
    let origin: CLLocation?
    var distanceLabel = "away"
    var body: some View {
        HStack(spacing: 14) {
            BusinessBadge(name: place.name)
            VStack(alignment: .leading, spacing: 5) {
                Text(place.name).font(.headline).foregroundStyle(.primary)
                Text(origin.map { "\(formattedDistance(place.distance(from: $0))) \(distanceLabel)" } ?? "Community shared").font(.caption).foregroundStyle(.secondary)
                if place.accessible { Label("Step-free · contributor reported", systemImage: "figure.roll").font(.caption2).foregroundStyle(violet) }
                if let summary = store.summaries[place.id] {
                    Text(summary.title).font(.caption2).foregroundStyle(summary.color)
                }
            }
            Spacer(minLength: 4)
            Text(place.code).font(.system(.title3, design: .monospaced).bold()).foregroundStyle(violet)
        }.padding(.vertical, 4)
    }
    private func formattedDistance(_ distance: Double) -> String {
        distance >= 1000 ? String(format: "%.1f km", distance / 1000) : "\(Int(distance)) m"
    }
}

struct PlaceDetail: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    let place: Place
    let origin: CLLocation?
    @State private var copied = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let path = place.photo_path, let url = store.photoURL(path) {
                        AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Rectangle().fill(violet.opacity(0.15)).overlay(ProgressView()) }.frame(height: 220).clipped().clipShape(RoundedRectangle(cornerRadius: 24))
                    }
                    HStack {
                        BusinessBadge(name: place.name, size: 56)
                        Text(place.name).font(.largeTitle.bold())
                        Spacer(minLength: 0)
                    }
                    Button {
                        Task { do { try await store.toggleSaved(place) } catch { store.message = error.localizedDescription } }
                    } label: {
                        Label(store.savedIDs.contains(place.id) ? "Saved place" : "Save for later", systemImage: store.savedIDs.contains(place.id) ? "bookmark.fill" : "bookmark")
                    }.buttonStyle(.bordered)
                    Label(place.address, systemImage: "mappin.and.ellipse").foregroundStyle(.secondary)
                    HStack {
                        ShareLink(item: "\(place.name)\n\(place.address)\nToilet code: \(place.code)\nCommunity shared on OpenWC; check venue access rules.") {
                            Label("Share place", systemImage: "square.and.arrow.up")
                        }
                        Spacer()
                        Button("Copy address") { UIPasteboard.general.string = place.address }
                    }.font(.subheadline)
                    VStack(alignment: .leading, spacing: 14) {
                        Text("TOILET ACCESS CODE").font(.caption.bold()).tracking(2).foregroundStyle(.secondary)
                        HStack { Text(place.code).font(.system(size: 38, weight: .bold, design: .monospaced)); Spacer(); Button { UIPasteboard.general.string = place.code; copied = true } label: { Image(systemName: copied ? "checkmark" : "doc.on.doc").font(.title2) }.accessibilityLabel(copied ? "Code copied" : "Copy code") }
                    }.padding(24).background(violet.opacity(0.14), in: RoundedRectangle(cornerRadius: 24))
                    if store.demo { Text("DEMO — fictional code, not for real use.").foregroundStyle(violet).font(.callout.bold()) }
                    Text(place.notes.isEmpty ? "No access notes have been added." : place.notes).foregroundStyle(.secondary)
                    if place.accessible { Label("Step-free access reported by contributor", systemImage: "figure.roll") }
                    Button { let item = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate)); item.name = place.name; item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking]) } label: { Label("Walking directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill").frame(maxWidth: .infinity).padding() }.buttonStyle(.borderedProminent)
                    Text("Community shared, not independently verified. Opening hours, access and codes can change. Follow the venue’s access rules.").font(.caption).foregroundStyle(.secondary)
                    CommunityStatusView(place: place)
                }.padding(24)
            }.toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .alert("OpenWC", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) { Button("OK") { store.message = nil } } message: { Text(store.message ?? "") }
        .presentationDetents([.large])
        .task { await store.loadCommunity() }
    }
}

struct SettingsView: View {
    @ObservedObject var location: LocationService
    var onChooseCity: () -> Void = {}
    @AppStorage("appearance") private var appearance = "dark"
    var body: some View {
        NavigationStack {
            Form {
                Section("Make it yours") {
                    Picker("Appearance", selection: $appearance) { Text("Dark purple").tag("dark"); Text("Light").tag("light"); Text("System").tag("system") }
                }
                Section("Location") {
                    Button("Choose city worldwide", action: onChooseCity)
                    Text("OpenWC uses your location to center the map and calculate distances. An approximate search center is sent to the database to find nearby codes; no location history is saved by the app. Apple Maps handles map and place searches. You can choose cities manually without location permission.")
                    Button("Open iOS settings") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
                }
                Section("Your data") {
                    NavigationLink("Data & community overview") { AnalyticsView() }
                    Text("The overview uses your contributions and code checks. It does not record a location history.").font(.caption).foregroundStyle(.secondary)
                }
                Section("The OpenWC spirit") {
                    Text("Share only codes you have permission to share. Add accurate access notes and keep photos free of people and private information.")
                    Text("Step-free labels are community reported and do not guarantee accessibility.").foregroundStyle(.secondary)
                }
                Section("Legal & privacy") {
                    ForEach(LegalDocument.allCases) { document in
                        NavigationLink(document.title) { LegalDocumentContent(document: document) }
                    }
                    NavigationLink("Privacy & account requests") { PrivacyRequestView() }
                    Text("© 2026 Vojtěch Klepáček. All rights reserved.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .safeAreaPadding(.bottom, 24)
            .navigationTitle("Your preferences.")
        }
    }
}

struct NavigationGlass: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: Capsule())
        } else {
            content.background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.18)))
        }
    }
}
