import SwiftUI
import MapKit

struct MapPinPicker: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var finder = BusinessFinder()
    @State private var position: MapCameraPosition
    @State private var center: CLLocationCoordinate2D
    @State private var settled: CLLocationCoordinate2D
    @State private var moving = false
    let onConfirm: (CLLocationCoordinate2D, MKMapItem?) -> Void
    @State private var searchRevision = 0
    @State private var waitingForSearch = true
    @State private var choosingCity = false

    init(initialCoordinate: CLLocationCoordinate2D?, onConfirm: @escaping (CLLocationCoordinate2D, MKMapItem?) -> Void) {
        let initial = initialCoordinate ?? CLLocationCoordinate2D(latitude: 50.082, longitude: 14.424)
        _center = State(initialValue: initial)
        _settled = State(initialValue: initial)
        _position = State(initialValue: .region(.init(center: initial, span: .init(latitudeDelta: 0.006, longitudeDelta: 0.006))))
        self.onConfirm = onConfirm
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("Move the pin near an entrance. We’ll suggest the nearest business returned by Apple Maps.")
                    .font(.callout).padding(16)
                Map(position: $position, interactionModes: [.pan, .zoom]) {
                    UserAnnotation()
                    if !moving, let item = finder.results.first {
                        Annotation(item.name ?? "Nearest business", coordinate: item.placemark.coordinate) {
                            BusinessBadge(name: item.name ?? "", size: 36)
                        }
                    }
                }
                .mapStyle(.standard(elevation: .flat))
                .onMapCameraChange(frequency: .continuous) { context in
                    center = context.region.center
                    if abs(center.latitude - settled.latitude) > 0.00001 || abs(center.longitude - settled.longitude) > 0.00001 { moving = true }
                }
                .onMapCameraChange(frequency: .onEnd) { context in
                    center = context.region.center
                    settled = context.region.center
                    finder.results = []
                    finder.error = nil
                    moving = false
                    waitingForSearch = true
                    searchRevision += 1
                }
                .overlay {
                    Image(systemName: "mappin").font(.system(size: 46, weight: .semibold)).foregroundStyle(violet)
                        .shadow(color: .black.opacity(0.35), radius: 4, y: 3)
                        .offset(y: -23).allowsHitTesting(false)
                }
                VStack(alignment: .leading, spacing: 12) {
                    if finder.searching || moving || waitingForSearch {
                        HStack { ProgressView(); Text("Finding the nearest business…").font(.subheadline) }
                    } else if let item = finder.results.first {
                        HStack {
                            BusinessBadge(name: item.name ?? "", size: 40)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.name ?? "Business").font(.headline)
                                Text("\(Int(BusinessFinder.distance(item, from: settled))) m from pin · nearest result").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Button {
                            onConfirm(item.placemark.coordinate, item); dismiss()
                        } label: {
                            Text("Use \(item.name ?? "nearest business")").fontWeight(.semibold).frame(maxWidth: .infinity).padding(10)
                        }.buttonStyle(.borderedProminent)
                    } else if let error = finder.error { Text(error).font(.caption).foregroundStyle(.secondary) }
                    Button("Keep exact pin instead") { onConfirm(center, nil); dismiss() }
                        .font(.subheadline).frame(maxWidth: .infinity).disabled(moving)
                    Text(String(format: "%.6f, %.6f", center.latitude, center.longitude))
                        .font(.caption2.monospaced()).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }.padding(20).background(.regularMaterial)
            }
            .navigationTitle("Find the entrance").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button { choosingCity = true } label: { Image(systemName: "globe") }.accessibilityLabel("Find a city or address") }
            }
            .sheet(isPresented: $choosingCity) {
                CitySearchView { area in
                    center = area.coordinate; settled = area.coordinate
                    position = .region(MKCoordinateRegion(center: area.coordinate, latitudinalMeters: 2000, longitudinalMeters: 2000))
                    searchRevision += 1
                }
            }
            .task(id: searchRevision) {
                do { try await Task.sleep(for: .milliseconds(550)); try Task.checkCancellation() }
                catch { return }
                waitingForSearch = false
                await finder.nearest(to: settled)
            }
            .onDisappear { finder.cancel() }
        }
    }
}
