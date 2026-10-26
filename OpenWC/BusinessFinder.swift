import Foundation
import MapKit

@MainActor
final class BusinessFinder: ObservableObject {
    @Published var results: [MKMapItem] = []
    @Published var searching = false
    @Published var error: String?
    private var activeSearch: MKLocalSearch?
    private var requestID = UUID()

    func cancel() {
        requestID = UUID()
        activeSearch?.cancel()
        searching = false
    }
    func search(_ text: String, near anchor: CLLocationCoordinate2D) async {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count >= 2 else { cancel(); results = []; error = nil; return }
        let token = begin()
        defer { if token == requestID { searching = false } }
        do {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = value
            request.resultTypes = .pointOfInterest
            request.region = MKCoordinateRegion(center: anchor, latitudinalMeters: 10000, longitudinalMeters: 10000)
            let search = MKLocalSearch(request: request)
            activeSearch = search
            let response = try await search.start()
            guard token == requestID, !Task.isCancelled else { return }
            let ranked = Self.sorted(response.mapItems, from: anchor)
            if !ranked.isEmpty { results = ranked; return }
            // A street/square query can anchor a business search even if it is not a business itself.
            request.resultTypes = .address
            let addressSearch = MKLocalSearch(request: request)
            activeSearch = addressSearch
            let addresses = try await addressSearch.start()
            guard token == requestID, !Task.isCancelled else { return }
            guard let address = Self.sorted(addresses.mapItems, from: anchor).first else {
                results = []; error = "No matches. Try a business name and city, or choose a map pin."; return
            }
            let items = try await nearbyItems(address.placemark.coordinate)
            guard token == requestID, !Task.isCancelled else { return }
            results = items
            if items.isEmpty { error = "No nearby business was returned. You can keep an exact pin and name it yourself." }
        } catch {
            guard token == requestID, !Task.isCancelled else { return }
            self.error = "Business search is unavailable. Try again or use an exact map pin."
            results = []
        }
    }
    func nearest(to coordinate: CLLocationCoordinate2D) async {
        let token = begin()
        defer { if token == requestID { searching = false } }
        do {
            let items = try await nearbyItems(coordinate)
            guard token == requestID, !Task.isCancelled else { return }
            results = items
            if items.isEmpty { error = "Apple Maps returned no business within 500 m. You can still use the exact pin." }
        } catch {
            guard token == requestID, !Task.isCancelled else { return }
            results = []; self.error = "Nearby businesses couldn’t be loaded. You can still use the exact pin."
        }
    }
    private func begin() -> UUID {
        activeSearch?.cancel()
        requestID = UUID(); searching = true; error = nil; results = []
        return requestID
    }
    private func nearbyItems(_ coordinate: CLLocationCoordinate2D) async throws -> [MKMapItem] {
        let request = MKLocalPointsOfInterestRequest(center: coordinate, radius: 500)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.restaurant, .cafe, .bakery, .brewery, .foodMarket, .hotel, .store, .shoppingMall, .gasStation])
        let search = MKLocalSearch(request: request)
        activeSearch = search
        let response = try await search.start()
        return Self.sorted(response.mapItems, from: coordinate).filter { Self.distance($0, from: coordinate) <= 500 }
    }
    static func distance(_ item: MKMapItem, from coordinate: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            .distance(from: CLLocation(latitude: item.placemark.coordinate.latitude, longitude: item.placemark.coordinate.longitude))
    }
    static func sorted(_ items: [MKMapItem], from coordinate: CLLocationCoordinate2D) -> [MKMapItem] {
        items.sorted { distance($0, from: coordinate) < distance($1, from: coordinate) }
    }
}
