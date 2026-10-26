import SwiftUI
import MapKit

struct CitySearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var searching = false
    @State private var error: String?
    @State private var activeSearch: MKLocalSearch?
    let onSelect: (BrowseArea) -> Void
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "globe.europe.africa.fill").foregroundStyle(violet)
                    TextField("City, district or address worldwide", text: $query)
                        .textInputAutocapitalization(.words).autocorrectionDisabled()
                        .accessibilityIdentifier("citySearchField")
                    if searching { ProgressView() }
                }.padding(16).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18)).padding(20)
                List {
                    if query.isEmpty {
                        Section {
                            Label("Explore any city", systemImage: "globe")
                            Text("Search a city, district or address in any country. Shared codes are added by the community; some areas may not have any yet.").font(.callout).foregroundStyle(.secondary)
                        }
                    }
                    if let error { Text(error).foregroundStyle(.secondary) }
                    ForEach(Array(results.enumerated()), id: \.offset) { _, item in
                        Button {
                            let name = item.placemark.locality ?? item.name ?? "Selected area"
                            onSelect(.from(item.placemark.coordinate, name: name))
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "mappin.and.ellipse").foregroundStyle(violet)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name ?? item.placemark.locality ?? "Location").font(.headline)
                                    Text(item.placemark.title ?? "").font(.caption).foregroundStyle(.secondary)
                                }
                            }.padding(.vertical, 5)
                        }.buttonStyle(.plain)
                    }
                }.listStyle(.insetGrouped)
            }
            .navigationTitle("Explore the world").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .task(id: query) {
                activeSearch?.cancel()
                results = []; error = nil; searching = false
                guard query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else { return }
                do { try await Task.sleep(for: .milliseconds(500)); try Task.checkCancellation() }
                catch { return }
                await search()
            }
            .onDisappear { activeSearch?.cancel() }
        }
    }
    private func search() async {
        let text = query
        searching = true
        defer { if text == query { searching = false } }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        request.resultTypes = .address
        // Intentionally no country or current-location region constraint.
        let search = MKLocalSearch(request: request); activeSearch = search
        do {
            let response = try await search.start()
            guard text == query, !Task.isCancelled else { return }
            results = response.mapItems
            if results.isEmpty { error = "No location returned. Try adding the country or a nearby address." }
        } catch {
            guard text == query, !Task.isCancelled else { return }
            self.error = "Location search is unavailable. You can still pan the map and search that area."
        }
    }
}
