import SwiftUI
import MapKit
import PhotosUI
import UIKit

struct AddPlaceView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    let regionCenter: CLLocationCoordinate2D?
    @State private var query = ""
    @StateObject private var finder = BusinessFinder()
    @State private var searchAnchor: CLLocationCoordinate2D?
    @State private var selectionNote: String?
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var businessName = ""
    @State private var address = ""
    @State private var choosingPin = false
    @State private var code = ""
    @State private var notes = ""
    @State private var accessible = false
    @State private var photoItem: PhotosPickerItem?
    @State private var photo: Data?
    @State private var working = false
    @State private var error: String?
    var valid: Bool { !finder.searching && coordinate != nil && !businessName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && businessName.count <= 200 && address.count <= 1000 && !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && code.count <= 32 && notes.count <= 1000 }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("One code. A lot of relief.").font(.title2.bold())
                    Text("Choose a business, add its toilet code, and help the next person.").foregroundStyle(.secondary)
                }.listRowBackground(Color.clear)
                if store.demo { Section { Text("You’re exploring a demo. Exit demo and log in to publish a place.").foregroundStyle(.purple) } }
                Section("1 · Pin the business") {
                    HStack {
                        TextField("Business name or address", text: $query).onSubmit { Task { await search() } }
                        Button { Task { await search() } } label: { if finder.searching { ProgressView() } else { Image(systemName: "magnifyingglass") } }.disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || finder.searching).accessibilityLabel("Search businesses")
                    }
                    Button { choosingPin = true } label: {
                        Label(coordinate == nil ? "Choose a spot on the map" : "Adjust the map pin", systemImage: "mappin.and.ellipse")
                    }
                    Text("Results are sorted by distance from your pin or current search area. The nearest match is selected automatically.")
                        .font(.caption).foregroundStyle(.secondary)
                    if let selectionNote { Text(selectionNote).font(.caption).foregroundStyle(.purple) }
                    if let searchError = finder.error { Text(searchError).font(.caption).foregroundStyle(.secondary) }
                    TextField("Business or place name", text: $businessName)
                    TextField("Street / address (optional)", text: $address)
                    if let coordinate {
                        Label("Location pinned", systemImage: "checkmark.circle.fill").foregroundStyle(.purple)
                        Map(initialPosition: .region(.init(center: coordinate, span: .init(latitudeDelta: 0.003, longitudeDelta: 0.003)))) {
                            Marker(businessName.isEmpty ? "Selected location" : businessName, coordinate: coordinate).tint(.purple)
                        }
                        .frame(height: 150).allowsHitTesting(false)
                        .id("\(coordinate.latitude),\(coordinate.longitude)")
                        Text(String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude))
                            .font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                    ForEach(Array(finder.results.enumerated()), id: \.offset) { _, item in
                        Button { choose(item, note: "Selected business. Adjust its pin if needed.")                        } label: {
                            HStack {
                                BusinessBadge(name: item.name ?? "", size: 36)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name ?? "Business")
                                    Text(item.placemark.title ?? "").font(.caption).foregroundStyle(.secondary)
                                    if let searchAnchor { Text("\(Int(BusinessFinder.distance(item, from: searchAnchor))) m from search area").font(.caption2).foregroundStyle(.secondary) }
                                }
                            }

                        }
                    }
                }
                Section("2 · Share access") {
                    TextField("Toilet code", text: $code).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("How to find it, access rules, opening hours…", text: $notes, axis: .vertical).lineLimit(3...6)
                    Toggle("Step-free access", isOn: $accessible)
                    Text("Share only codes you have permission to share. Don’t include personal information.").font(.caption).foregroundStyle(.secondary)
                }
                Section("3 · Add a photo (optional)") {
                    PhotosPicker(selection: $photoItem, matching: .images) { Label(photo == nil ? "Choose a photo" : "Change photo", systemImage: "camera") }
                    if let photo, let image = UIImage(data: photo) { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 180); Button("Remove photo", role: .destructive) { self.photo = nil; photoItem = nil } }
                    Text("Choose a useful entrance or toilet photo without people.").font(.caption).foregroundStyle(.secondary)
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
                Section {
                    Button { Task { await save() } } label: { HStack { Text("Share this place"); Spacer(); if working { ProgressView() } else { Image(systemName: "arrow.up.right") } } }.disabled(!valid || working || store.demo)
                }
            }.navigationTitle("Share a little relief")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(working) } }
                .interactiveDismissDisabled(working)
                .sheet(isPresented: $choosingPin) {
                    MapPinPicker(initialCoordinate: coordinate ?? regionCenter) { value, item in
                        coordinate = value
                        if let item { choose(item, note: "Nearest business to your pin selected.") }
                        else { selectionNote = "Exact pin kept. Check the business name and address." }
                    }
                }
                .task(id: query) {
                    do { try await Task.sleep(for: .milliseconds(550)); try Task.checkCancellation() }
                    catch { return }
                    if query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 { await search() }
                    else { finder.cancel(); finder.results = [] }
                }
                .onDisappear { finder.cancel() }
                .onChange(of: photoItem) { _, item in
                    Task {
                        do {
                            guard let data = try await item?.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return }
                            guard data.count <= 25_000_000 else { error = "Choose an image smaller than 25 MB."; return }
                            let scale = min(1, 1600 / max(image.size.width, image.size.height))
                            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                            let format = UIGraphicsImageRendererFormat(); format.scale = 1
                            let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
                            guard let jpeg = resized.jpegData(compressionQuality: 0.78), jpeg.count <= 5_000_000 else { error = "This photo is too large. Choose a smaller one."; return }
                            photo = jpeg
                        } catch { self.error = error.localizedDescription }
                    }
                }
        }
    }
    func choose(_ item: MKMapItem, note: String) {
        coordinate = item.placemark.coordinate
        businessName = item.name ?? ""
        address = item.placemark.title ?? ""
        selectionNote = note
    }
    func search() async {
        error = nil
        let anchor = coordinate ?? regionCenter ?? CLLocationCoordinate2D(latitude: 50.082, longitude: 14.424)
        searchAnchor = anchor
        await finder.search(query, near: anchor)
        guard !Task.isCancelled else { return }
        if let item = finder.results.first { choose(item, note: "Nearest search result selected. You can choose another below.") }
    }
    func save() async {
        guard let coordinate, valid else { return }
        working = true; error = nil
        defer { working = false }
        do {
            try await store.add(name: businessName.trimmingCharacters(in: .whitespacesAndNewlines), address: address.trimmingCharacters(in: .whitespacesAndNewlines), coordinate: coordinate, code: code.trimmingCharacters(in: .whitespacesAndNewlines), notes: notes.trimmingCharacters(in: .whitespacesAndNewlines), accessible: accessible, photo: photo)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
