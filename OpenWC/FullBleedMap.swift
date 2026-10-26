import SwiftUI
import MapKit

/// Layout margins move MapKit controls without reducing the map's drawing surface.
struct FullBleedMap: UIViewRepresentable {
    let requestedRegion: MKCoordinateRegion?
    let places: [Place]
    let footerInset: CGFloat
    let showUserLocation: Bool
    let onMove: (MKCoordinateRegion) -> Void
    let onSelect: (Place) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.accessibilityIdentifier = "mainMap"
        let configuration = MKStandardMapConfiguration(elevationStyle: .flat)
        configuration.emphasisStyle = .muted
        configuration.pointOfInterestFilter = .excludingAll
        map.preferredConfiguration = configuration
        map.showsCompass = false
        map.showsScale = false
        map.isRotateEnabled = false
        map.insetsLayoutMarginsFromSafeArea = true
        if let requestedRegion {
            map.setRegion(requestedRegion, animated: false)
            context.coordinator.lastRegion = requestedRegion
        }
        map.delegate = context.coordinator
        return map
    }
    func updateUIView(_ map: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        // Leave room above the floating search/location controls for MapKit attribution.
        map.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: footerInset + 72, right: 12)
        map.showsUserLocation = showUserLocation
        if let requestedRegion, !Coordinator.same(requestedRegion, coordinator.lastRegion) {
            coordinator.lastRegion = requestedRegion
            map.setRegion(requestedRegion, animated: true)
        }
        if coordinator.lastPlaces != places {
            coordinator.lastPlaces = places
            map.removeAnnotations(map.annotations.filter { !($0 is MKUserLocation) })
            map.addAnnotations(places.map { BusinessAnnotation(place: $0) })
        }
    }
    @MainActor
    final class Coordinator: NSObject, @preconcurrency MKMapViewDelegate {
        var parent: FullBleedMap
        var lastRegion: MKCoordinateRegion?
        var lastPlaces: [Place] = []
        init(parent: FullBleedMap) { self.parent = parent }
        static func same(_ first: MKCoordinateRegion, _ second: MKCoordinateRegion?) -> Bool {
            guard let second else { return false }
            return abs(first.center.latitude-second.center.latitude)<0.000001 &&
                abs(first.center.longitude-second.center.longitude)<0.000001 &&
                abs(first.span.latitudeDelta-second.span.latitudeDelta)<0.000001 &&
                abs(first.span.longitudeDelta-second.span.longitudeDelta)<0.000001
        }
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let region = mapView.region
            DispatchQueue.main.async { [weak self] in self?.parent.onMove(region) }
        }
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            if let cluster = annotation as? MKClusterAnnotation {
                let view = (mapView.dequeueReusableAnnotationView(withIdentifier: "cluster") as? MKMarkerAnnotationView) ?? MKMarkerAnnotationView(annotation: cluster, reuseIdentifier: "cluster")
                view.annotation = cluster; view.markerTintColor = UIColor.systemPurple
                view.glyphText = "\(cluster.memberAnnotations.count)"
                return view
            }
            guard let business = annotation as? BusinessAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: "business") ?? MKAnnotationView(annotation: business, reuseIdentifier: "business")
            view.annotation = business
            view.image = ImageRenderer(content: Pin(name: business.place.name)).uiImage
            view.centerOffset = CGPoint(x: 0, y: -24)
            view.clusteringIdentifier = "business"
            view.collisionMode = .circle
            view.displayPriority = .defaultHigh
            view.isAccessibilityElement = true
            view.accessibilityLabel = "View \(business.place.name)"
            return view
        }
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let business = view.annotation as? BusinessAnnotation {
                parent.onSelect(business.place)
                mapView.deselectAnnotation(business, animated: false)
            } else if let cluster = view.annotation as? MKClusterAnnotation {
                let span = MKCoordinateSpan(latitudeDelta: mapView.region.span.latitudeDelta * 0.4, longitudeDelta: mapView.region.span.longitudeDelta * 0.4)
                mapView.setRegion(MKCoordinateRegion(center: cluster.coordinate, span: span), animated: true)
            }
        }
    }
}

private final class BusinessAnnotation: NSObject, MKAnnotation {
    let place: Place
    var coordinate: CLLocationCoordinate2D { place.coordinate }
    var title: String? { place.name }
    init(place: Place) { self.place = place }
}
