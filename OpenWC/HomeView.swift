import SwiftUI
import MapKit

private struct MapFooterHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 220
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct HomeView: View {
    @EnvironmentObject var store: AppStore
    @StateObject private var location = LocationService()
    @State private var tab = 0
    @State private var adding = false
    @State private var choosingCity = false
    @State private var selected: Place?
    @State private var search = ""
    @State private var accessibleOnly = false
    @State private var savedOnly = false
    @State private var recheckOnly = false
    @State private var sorting: PlaceSort = .nearest
    @State private var usedInitialLocation = false
    @State private var waitingForLocation = false
    @State private var footerHeight: CGFloat = 220
    @State private var viewport: MKCoordinateRegion?
    @State private var position: MapCameraPosition = .region(.init(center: .init(latitude: 20, longitude: 0), span: .init(latitudeDelta: 120, longitudeDelta: 170)))
    private var origin: CLLocation? { store.browseArea?.location ?? location.location }
    private var radius: Int { store.browseArea?.radius ?? 10000 }
    private var filtered: [Place] {
        let source: [Place] = savedOnly ? store.savedPlaces : store.places
        let center = origin
        let limit = Double(radius)
        let items: [Place] = source.filter { place in
            if accessibleOnly && !place.accessible { return false }
            if recheckOnly && store.summaries[place.id]?.needsRecheck != true { return false }
            if !search.isEmpty {
                let matchesName = place.name.localizedStandardContains(search)
                let matchesAddress = place.address.localizedStandardContains(search)
                if !matchesName && !matchesAddress { return false }
            }
            if !savedOnly, let center, place.distance(from: center) > limit { return false }
            return true
        }
        return items.sorted { isBefore($0, $1, center: center) }
    }
    private func isBefore(_ first: Place, _ second: Place, center: CLLocation?) -> Bool {
        if sorting == .newest {
            let firstDate = first.created_at ?? ""
            let secondDate = second.created_at ?? ""
            if firstDate != secondDate { return firstDate > secondDate }
        }
        if sorting == .confirmed {
            let firstCount = store.summaries[first.id]?.working_count ?? 0
            let secondCount = store.summaries[second.id]?.working_count ?? 0
            if firstCount != secondCount { return firstCount > secondCount }
        }
        if let center { return first.distance(from: center) < second.distance(from: center) }
        return first.name.localizedStandardCompare(second.name) == .orderedAscending
    }
    var body: some View {
        Group {
            if tab == 0 { mapPage }
            else {
                VStack(spacing: 0) {
                    Group {
                        if tab == 1 { listPage }
                        else if tab == 3 { ProfilePage() }
                        else { SettingsView(location: location) { choosingCity = true } }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
                    navigation
                }.background(Color(uiColor: .systemBackground))
            }
        }
        .alert("OpenWC", isPresented: Binding(get: { store.message != nil && selected == nil && !adding && tab != 3 }, set: { if !$0 { store.message = nil } })) {
            Button("OK") { store.message = nil }
        } message: { Text(store.message ?? "") }
        .sheet(isPresented: $adding) { AddPlaceView(regionCenter: viewport?.center ?? store.browseArea?.coordinate ?? location.location?.coordinate) }
        .sheet(item: $selected) { PlaceDetail(place: $0, origin: origin) }
        .sheet(isPresented: $choosingCity) {
            CitySearchView { area in selectArea(area) }
        }
        .task {
            if let area = store.browseArea { center(area.coordinate) }
            if !store.demo { location.request(); await store.load() }
        }
        .onChange(of: location.location) { _, value in
            if let value, !store.demo, waitingForLocation || (!usedInitialLocation && store.browseArea == nil) {
                usedInitialLocation = true
                waitingForLocation = false
                selectArea(.from(value.coordinate, name: "Near me"))
            }
        }
    }
    private var mapPage: some View {
        ZStack {
            nativeMap
            VStack(spacing: 0) {
                mapHeader
                Spacer(minLength: 8)
                VStack(spacing: 12) {
                    HStack {
                        Button { searchViewport() } label: {
                            Label(store.loading ? "Searching…" : "Search this area", systemImage: "arrow.clockwise")
                                .font(.caption.bold()).padding(12).background(.regularMaterial, in: Capsule())
                        }.disabled(store.loading).accessibilityIdentifier("searchThisArea")
                        Spacer()
                        Button { locate() } label: {
                            Image(systemName: "location.fill").padding(15).background(.regularMaterial, in: Circle())
                        }.accessibilityLabel("Center on my location")
                    }.padding(.horizontal, 20)
                    mapCard.padding(.horizontal, 18)
                    navigation
                }
                .background(GeometryReader { geometry in Color.clear.preference(key: MapFooterHeightKey.self, value: geometry.size.height) })
            }
        }
        .onPreferenceChange(MapFooterHeightKey.self) { if abs(footerHeight - $0) > 1 { footerHeight = $0 } }
    }
    private var nativeMap: some View {
            Map(position: $position) {
                UserAnnotation()
                ForEach(filtered) { place in
                    Annotation(place.name, coordinate: place.coordinate, anchor: .bottom) {
                        Button { selected = place } label: { Pin(name: place.name) }
                            .buttonStyle(.plain).accessibilityLabel("View \(place.name)")
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .safeAreaPadding(.bottom, footerHeight)
            .ignoresSafeArea(.container)
            .accessibilityIdentifier("mainMap")
            .onMapCameraChange(frequency: .onEnd) { viewport = $0.region }
    }
    @ViewBuilder private var mapCard: some View {
        if store.browseArea == nil && !store.demo {
            Button { choosingCity = true } label: {
                VStack(alignment: .leading, spacing: 7) {
                    Label("Where are you heading?", systemImage: "globe").font(.headline)
                    Text("Choose a city anywhere in the world, or search the map area.").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(18)
            }.buttonStyle(.plain).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        } else if let place = filtered.first {
            Button { selected = place } label: { PlaceRow(place: place, origin: origin, distanceLabel: "from search center") }
                .buttonStyle(.plain).padding(18).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26))
                .accessibilityIdentifier("mapPlaceCard")
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Label(store.loading ? "Finding shared codes…" : "A little relief starts with you.", systemImage: "mappin.and.ellipse").font(.headline)
                Text("No matching shared codes in this area yet. Try another area or share a permitted code.").font(.caption).foregroundStyle(.secondary)
                Button("Share the first place") { adding = true }.font(.caption.bold())
            }.frame(maxWidth: .infinity, alignment: .leading).padding(18).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        }
    }
    private var mapHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("OpenWC").font(.system(size: 30, weight: .bold, design: .rounded)).tracking(-1)
                    Text(store.browseArea?.name.uppercased() ?? "A MORE OPEN WORLD")
                        .font(.system(size: 10, weight: .bold)).tracking(1.7).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Button { choosingCity = true } label: {
                    Image(systemName: "globe").font(.title2).padding(12).background(.regularMaterial, in: Circle())
                }.accessibilityLabel("Choose city worldwide").accessibilityIdentifier("chooseCityButton")
            }
            searchField(prompt: "Find shared places in this area…")
            HStack(spacing: 8) {
                Label("\(filtered.count) shared", systemImage: "mappin.and.ellipse").font(.caption.bold()).padding(10).background(.regularMaterial, in: Capsule())
                filterChip("Step-free", symbol: "figure.roll", selected: $accessibleOnly)
                radiusMenu
            }
            if savedOnly || recheckOnly {
                Button("Clear Saved / Needs recheck filters") { savedOnly = false; recheckOnly = false }.font(.caption)
            }
        }.padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 16)
            .background(LinearGradient(colors: [Color(uiColor: .systemBackground).opacity(0.9), .clear], startPoint: .top, endPoint: .bottom))
    }
    private var navigation: some View {
        HStack(spacing: 0) {
            navItem("Map", "map", 0)
            navItem("Nearby", "list.bullet", 1)
            Button { adding = true } label: {
                Image(systemName: "plus").font(.system(size: 27, weight: .medium)).foregroundStyle(.black)
                    .frame(width: 60, height: 60).background(LinearGradient(colors: [Color(red: 0.82, green: 0.71, blue: 1), violet], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                    .shadow(color: violet.opacity(0.35), radius: 12, y: 4)
            }.accessibilityLabel("Share a toilet code").accessibilityIdentifier("sharePlaceButton").frame(maxWidth: .infinity)
            navItem("Profile", "person.crop.circle", 3)
            navItem("Settings", "slider.horizontal.3", 4)
        }.padding(9).modifier(NavigationGlass()).shadow(color: .black.opacity(0.18), radius: 20, y: 8)
            .padding(.horizontal, 18).padding(.top, 4).padding(.bottom, 12)
    }
    private func navItem(_ name: String, _ symbol: String, _ value: Int) -> some View {
        Button { tab = value } label: {
            VStack(spacing: 5) { Image(systemName: symbol).font(.system(size: 21)); Text(name).font(.system(size: 9, weight: .medium)) }
                .foregroundStyle(tab == value ? violet : .secondary).frame(maxWidth: .infinity).frame(height: 60)
        }.accessibilityIdentifier("tab-\(value)")
    }
    private var listPage: some View {
        NavigationStack {
            List {
                if store.demo { Text("Demo listings and codes are fictional.").foregroundStyle(violet) }
                if store.areaHasMore { Text("Showing the nearest 200 results. Zoom in to narrow the area.").font(.caption).foregroundStyle(.secondary) }
                ForEach(filtered) { place in
                    Button { selected = place } label: { PlaceRow(place: place, origin: origin, distanceLabel: "from search center") }.buttonStyle(.plain)
                }
                if filtered.isEmpty { ContentUnavailableView("No shared codes here yet", systemImage: "mappin.slash", description: Text("Choose another city, expand the radius, clear filters, or share the first place.")) }
            }
            .navigationTitle(savedOnly ? "Saved worldwide" : store.browseArea?.name ?? "Explore worldwide")
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 10) {
                    searchField(prompt: "Search nearby places").accessibilityIdentifier("nearbySearchContainer")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Button { choosingCity = true } label: { Label("City", systemImage: "globe").font(.caption.bold()).padding(10) }
                            filterChip("Saved", symbol: "bookmark", selected: $savedOnly)
                            filterChip("Step-free", symbol: "figure.roll", selected: $accessibleOnly)
                            filterChip("Needs recheck", symbol: "exclamationmark.bubble", selected: $recheckOnly)
                            radiusMenu
                            Menu { Picker("Sort places", selection: $sorting) { ForEach(PlaceSort.allCases) { Text($0.rawValue).tag($0) } } } label: {
                                Label(sorting.rawValue, systemImage: "arrow.up.arrow.down").font(.caption.bold()).padding(10)
                            }
                        }
                    }
                }.padding(.horizontal, 20).padding(.vertical, 10).background(Color(uiColor: .systemBackground))
            }
            .safeAreaPadding(.bottom, 20).scrollDismissesKeyboard(.interactively).refreshable { await store.load() }
        }
    }
    private func searchField(prompt: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass").foregroundStyle(violet)
            TextField(prompt, text: $search).textInputAutocapitalization(.never).autocorrectionDisabled()
                .accessibilityIdentifier(tab == 1 ? "nearbySearch" : "mapPlaceSearch")
            if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("Clear search") }
        }.padding(15).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
    private func filterChip(_ title: String, symbol: String, selected: Binding<Bool>) -> some View {
        Button { selected.wrappedValue.toggle() } label: {
            Label(title, systemImage: symbol).font(.caption.bold()).padding(.horizontal, 10).padding(.vertical, 10)
                .background(selected.wrappedValue ? violet.opacity(0.25) : Color(uiColor: .secondarySystemBackground).opacity(0.75), in: Capsule())
        }.buttonStyle(.plain)
    }
    private var radiusMenu: some View {
        Menu {
            ForEach([5000,10000,25000,50000], id: \.self) { metres in
                Button("\(metres/1000) km") {
                    if var area = store.browseArea { area.radius = metres; Task { await store.loadArea(area) } }
                    else { choosingCity = true }
                }
            }
        } label: { Label(radius < 1000 ? "\(radius) m" : "\(radius/1000) km", systemImage: "circle.dashed").font(.caption.bold()).padding(10).background(.regularMaterial, in: Capsule()) }
    }
    private func center(_ coordinate: CLLocationCoordinate2D, radiusM: Int? = nil) {
        let distance = Double(radiusM ?? radius) * 2
        withAnimation { position = .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: distance, longitudinalMeters: distance)) }
    }
    private func selectArea(_ area: BrowseArea) {
        tab = 0; search = ""; savedOnly = false; recheckOnly = false
        usedInitialLocation = true
        center(area.coordinate, radiusM: area.radius)
        Task { await store.loadArea(area) }
    }
    private func locate() {
        if let current = location.location { selectArea(.from(current.coordinate, name: "Near me", radius: radius)) }
        else {
            location.request()
            if location.denied { choosingCity = true }
            else { waitingForLocation = true }
        }
    }
    private func searchViewport() {
        guard let viewport else { choosingCity = true; return }
        let metres = Int(min(50000, max(500, abs(viewport.span.latitudeDelta) * 111000 / 2)))
        let area = BrowseArea.from(viewport.center, name: "Map area", radius: metres)
        usedInitialLocation = true
        Task { await store.loadArea(area) }
    }
}
