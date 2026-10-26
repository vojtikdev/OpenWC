import Foundation
import MapKit
import CoreLocation

struct Place: Identifiable, Codable, Hashable {
    var id: UUID
    var user_id: UUID
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    var code: String
    var notes: String
    var accessible: Bool
    var photo_path: String?
    var created_at: String?
    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
    func distance(from location: CLLocation) -> Double {
        location.distance(from: CLLocation(latitude: latitude, longitude: longitude))
    }
    static let samples: [Place] = [
        ("McDonald’s", "Václavské náměstí · Demo", 50.0823, 14.4260, "1234", false),
        ("Neighbourhood café", "Jungmannova · Demo", 50.0808, 14.4220, "2580", true),
        ("Burger King", "Národní · Demo", 50.0814, 14.4190, "4321", false)
    ].map { Place(id: UUID(), user_id: UUID(), name: $0.0, address: $0.1, latitude: $0.2, longitude: $0.3, code: $0.4, notes: "Sample listing. This code is fictional and has not been verified.", accessible: $0.5) }
}

@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation?
    @Published var denied = false
    private let manager = CLLocationManager()
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    func request() {
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        else if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways { manager.requestLocation() }
        else { denied = true }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        denied = manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways { manager.requestLocation() }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) { location = locations.last }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
