import Foundation
import CoreLocation
import MapKit

struct BrowseArea: Equatable {
    let latitude: Double
    let longitude: Double
    var radius: Int = 10000
    var name: String
    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
    var location: CLLocation { .init(latitude: latitude, longitude: longitude) }
    static func from(_ coordinate: CLLocationCoordinate2D, name: String, radius: Int = 10000) -> BrowseArea {
        .init(latitude: coordinate.latitude, longitude: coordinate.longitude, radius: radius, name: name)
    }
}

enum PlaceSort: String, CaseIterable, Identifiable {
    case nearest = "Nearest"
    case newest = "Newest"
    case confirmed = "Most confirmed"
    var id: String { rawValue }
}
