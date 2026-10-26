import SwiftUI
import MapKit

struct MapPinPicker: View {
    @Environment(\.dismiss) private var dismiss
    @State private var position: MapCameraPosition
    @State private var center: CLLocationCoordinate2D
    let onConfirm: (CLLocationCoordinate2D) -> Void

    init(initialCoordinate: CLLocationCoordinate2D?, onConfirm: @escaping (CLLocationCoordinate2D) -> Void) {
        let initial = initialCoordinate ?? CLLocationCoordinate2D(latitude: 50.082, longitude: 14.424)
        _center = State(initialValue: initial)
        _position = State(initialValue: .region(.init(center: initial, span: .init(latitudeDelta: 0.008, longitudeDelta: 0.008))))
        self.onConfirm = onConfirm
    }
    var body: some View {
        NavigationStack {
            Map(position: $position, interactionModes: [.pan, .zoom]) {
                UserAnnotation()
            }
            .mapStyle(.standard(elevation: .flat))
            .onMapCameraChange(frequency: .continuous) { context in
                center = context.region.center
            }
            .overlay {
                // The tip is exactly at the viewport center used by MapCameraUpdateContext.
                Image(systemName: "mappin")
                    .font(.system(size: 46, weight: .semibold)).foregroundStyle(violet)
                    .shadow(color: .black.opacity(0.35), radius: 4, y: 3)
                    .offset(y: -23).allowsHitTesting(false)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                Text("Move and zoom the map to put the pin at the entrance.")
                    .font(.callout).padding(16).frame(maxWidth: .infinity)
                    .background(.regularMaterial)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 12) {
                    Text(String(format: "%.6f, %.6f", center.latitude, center.longitude))
                        .font(.caption.monospaced()).foregroundStyle(.secondary)
                    Button {
                        onConfirm(center)
                        dismiss()
                    } label: {
                        Label("Use this location", systemImage: "checkmark")
                            .fontWeight(.semibold).frame(maxWidth: .infinity).padding(15)
                    }.buttonStyle(.borderedProminent)
                }.padding(20).background(.regularMaterial)
            }
            .navigationTitle("Pin the entrance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
