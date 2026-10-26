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

struct HomeView: View {
    @EnvironmentObject var store: AppStore
    @StateObject private var location = LocationService()
    @State private var tab = 0
    @State private var adding = false
    @State private var selected: Place?
    @State private var search = ""
    @State private var accessibleOnly = false
    @State private var savedOnly = false
    @State private var recheckOnly = false
    @State private var position: MapCameraPosition = .region(.init(center: .init(latitude: 50.082, longitude: 14.424), span: .init(latitudeDelta: 0.015, longitudeDelta: 0.015)))
    var filtered: [Place] {
        let items = store.places.filter { (!accessibleOnly || $0.accessible) && (!savedOnly || store.savedIDs.contains($0.id)) && (!recheckOnly || store.summaries[$0.id]?.needsRecheck == true) && (search.isEmpty || $0.name.localizedStandardContains(search) || $0.address.localizedStandardContains(search)) }
        guard let current = origin else { return items }
        return items.filter { $0.distance(from: current) <= 5000 }.sorted { $0.distance(from: current) < $1.distance(from: current) }
    }
    var origin: CLLocation? { store.demo ? CLLocation(latitude: 50.082, longitude: 14.424) : location.location }
    var body: some View {
        VStack(spacing: 0) {
          ZStack(alignment: .bottom) {
            if tab == 0 {
                Map(position: $position) {
                    UserAnnotation()
                    ForEach(filtered) { place in
                        Annotation(place.name, coordinate: place.coordinate, anchor: .bottom) {
                            Button { selected = place } label: { Pin(name: place.name) }.buttonStyle(.plain).accessibilityLabel("View \(place.name)")
                        }
                    }
                }.mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll)).ignoresSafeArea(.container, edges: .top)
                    .overlay(alignment: .top) { mapHeader }
                    .overlay(alignment: .bottomTrailing) {
                        Button { location.request(); if let origin { center(origin.coordinate) } } label: { Image(systemName: "location.fill").padding(16).background(.regularMaterial, in: Circle()) }
                            .accessibilityLabel("Center on my location").padding(.trailing, 20).padding(.bottom, 140)
                    }
                VStack(spacing: 12) {
                    if let place = filtered.first {
                        Button { selected = place } label: { PlaceRow(place: place, origin: origin) }.buttonStyle(.plain)
                            .padding(18).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26)).overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.12)))
                    } else {
                        Text(store.loading ? "Finding shared places…" : "No shared places here yet. Be the first to add one.").padding(20).frame(maxWidth: .infinity).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
                    }
                }.padding(.horizontal, 18).padding(.bottom, 16)
            } else if tab == 1 { listPage }
            else if tab == 3 { profilePage }
            else { SettingsView(location: location) }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .clipped()
          navigation
        }
        .background(Color(uiColor: .systemBackground))
        .alert("OpenWC", isPresented: Binding(get: { store.message != nil && selected == nil && !adding }, set: { if !$0 { store.message = nil } })) {
            Button("OK") { store.message = nil }
        } message: { Text(store.message ?? "") }
        .sheet(isPresented: $adding) { AddPlaceView(regionCenter: origin?.coordinate) }
        .sheet(item: $selected) { PlaceDetail(place: $0, origin: origin) }
        .task { if !store.demo { location.request() }; await store.load() }
        .onChange(of: location.location) { _, value in if let value, !store.demo { center(value.coordinate) } }
    }
    func center(_ value: CLLocationCoordinate2D) { withAnimation { position = .region(.init(center: value, span: .init(latitudeDelta: 0.015, longitudeDelta: 0.015))) } }
    var mapHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("OpenWC").font(.system(size: 30, weight: .bold, design: .rounded)).tracking(-1)
                    Text(store.demo ? "PRAGUE · DEMO" : "A MORE OPEN CITY").font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "drop.circle.fill").font(.system(size: 38)).foregroundStyle(violet)
            }
            HStack { Image(systemName: "magnifyingglass").foregroundStyle(violet); TextField("Find a little relief…", text: $search); if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill") } } }
                .padding(17).background(.regularMaterial, in: Capsule())
            HStack {
                Label("\(filtered.count) shared places", systemImage: "mappin.and.ellipse").font(.caption.bold()).padding(11).background(.regularMaterial, in: Capsule())
                Button { accessibleOnly.toggle() } label: { Label("Step-free", systemImage: "figure.roll").font(.caption.bold()).padding(11).background(accessibleOnly ? violet.opacity(0.65) : Color.clear, in: Capsule()).background(.regularMaterial, in: Capsule()) }
            }
            if location.denied && !store.demo { Text("Location is off. Enable it in Settings to find the nearest places.").font(.caption).padding(10).background(.regularMaterial, in: Capsule()) }
        }.padding(20).background(LinearGradient(colors: [Color(uiColor: .systemBackground).opacity(0.95), .clear], startPoint: .top, endPoint: .bottom))
    }
    var navigation: some View {
        HStack(spacing: 0) {
            navItem("Map", "map", 0)
            navItem("Nearby", "list.bullet", 1)
            Button { adding = true } label: { Image(systemName: "plus").font(.system(size: 27, weight: .medium)).foregroundStyle(.black).frame(width: 60, height: 60).background(LinearGradient(colors: [Color(red: 0.82, green: 0.71, blue: 1), violet], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle()).shadow(color: violet.opacity(0.4), radius: 15, y: 5) }.accessibilityLabel("Share a toilet code").accessibilityIdentifier("sharePlaceButton").frame(maxWidth: .infinity)
            navItem("Profile", "person.crop.circle", 3)
            navItem("Settings", "slider.horizontal.3", 4)
        }.padding(9).modifier(NavigationGlass()).shadow(color: .black.opacity(0.18), radius: 24, y: 10).padding(.horizontal, 18).padding(.bottom, 16)
    }
    func navItem(_ name: String, _ symbol: String, _ value: Int) -> some View {
        Button { tab = value } label: { VStack(spacing: 5) { Image(systemName: symbol).font(.system(size: 21)); Text(name).font(.system(size: 9, weight: .medium)) }.foregroundStyle(tab == value ? violet : .secondary).frame(maxWidth: .infinity).frame(height: 60) }.accessibilityIdentifier("tab-\(value)")
    }
    var listPage: some View {
        NavigationStack {
            List {
                if origin == nil { Text("Enable location to show shared places within 5 km, sorted by distance.").foregroundStyle(.secondary) }
                if store.demo { Text("Demo listings and codes are fictional.").foregroundStyle(violet) }
                ForEach(filtered) { place in Button { selected = place } label: { PlaceRow(place: place, origin: origin) }.buttonStyle(.plain) }
                if filtered.isEmpty { ContentUnavailableView("No places found", systemImage: "mappin.slash", description: Text("Try another search or share the first place.")) }
            }
            .navigationTitle("A little closer.")
            .safeAreaInset(edge: .top, spacing: 0) {
              VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass").foregroundStyle(violet)
                    TextField("Search nearby places", text: $search)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("nearbySearch")
                    if !search.isEmpty {
                        Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .accessibilityLabel("Clear search")
                    }
                }
                .padding(15).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal, 20).padding(.vertical, 10)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip("Saved", symbol: "bookmark", selected: $savedOnly)
                        filterChip("Step-free", symbol: "figure.roll", selected: $accessibleOnly)
                        filterChip("Needs recheck", symbol: "exclamationmark.bubble", selected: $recheckOnly)
                    }.padding(.horizontal, 20).padding(.bottom, 10)
                }
              }.background(Color(uiColor: .systemBackground))
            }
            .safeAreaPadding(.bottom, 20)
            .scrollDismissesKeyboard(.interactively)
            .refreshable { await store.load() }
        }
    }
    func filterChip(_ title: String, symbol: String, selected: Binding<Bool>) -> some View {
        Button { selected.wrappedValue.toggle() } label: {
            Label(title, systemImage: symbol).font(.caption.bold()).padding(.horizontal, 12).padding(.vertical, 9)
                .background(selected.wrappedValue ? violet.opacity(0.25) : Color(uiColor: .secondarySystemBackground), in: Capsule())
        }.buttonStyle(.plain)
    }
    var profilePage: some View { ProfilePage() }

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
    var body: some View {
        HStack(spacing: 14) {
            BusinessBadge(name: place.name)
            VStack(alignment: .leading, spacing: 5) {
                Text(place.name).font(.headline).foregroundStyle(.primary)
                Text(origin.map { "\(Int(place.distance(from: $0))) m away · Community shared" } ?? "Community shared").font(.caption).foregroundStyle(.secondary)
                if place.accessible { Label("Step-free · contributor reported", systemImage: "figure.roll").font(.caption2).foregroundStyle(violet) }
                if let summary = store.summaries[place.id] {
                    Text(summary.title).font(.caption2).foregroundStyle(summary.color)
                }
            }
            Spacer(minLength: 4)
            Text(place.code).font(.system(.title3, design: .monospaced).bold()).foregroundStyle(violet)
        }.padding(.vertical, 4)
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
    @AppStorage("appearance") private var appearance = "dark"
    var body: some View {
        NavigationStack {
            Form {
                Section("Make it yours") {
                    Picker("Appearance", selection: $appearance) { Text("Dark purple").tag("dark"); Text("Light").tag("light"); Text("System").tag("system") }
                }
                Section("Location") {
                    Text("OpenWC uses your location on device to center the map and calculate distances. Apple Maps may receive map or search-region information. You can also select places manually without location access.")
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
