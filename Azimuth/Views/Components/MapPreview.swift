import SwiftUI
import MapKit
import CoreLocation

struct MapPreview: View {
    let location: CLLocation?

    @State private var camera: MapCameraPosition = .automatic

    var body: some View {
        Group {
            if let location {
                Map(position: $camera, interactionModes: []) {
                    Annotation("", coordinate: location.coordinate) {
                        ZStack {
                            Circle()
                                .fill(Theme.sky.opacity(0.25))
                                .frame(width: 36, height: 36)
                            Circle()
                                .fill(Theme.skyDeep)
                                .frame(width: 14, height: 14)
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                        }
                    }
                }
                .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
                .disabled(true)
                .overlay(alignment: .bottomLeading) {
                    coordinatePill(for: location)
                        .padding(12)
                }
                .onAppear { recenter(on: location) }
                .onChange(of: location) { _, new in recenter(on: new) }
            } else {
                placeholder
            }
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Theme.cardStroke, lineWidth: 0.7)
        )
        .shadow(color: Theme.skyDeep.opacity(0.12), radius: 18, x: 0, y: 8)
    }

    private var placeholder: some View {
        ZStack {
            Rectangle().fill(Theme.cardFill)
            VStack(spacing: 10) {
                Image(systemName: "location.viewfinder")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Theme.sky)
                    .symbolEffect(.pulse, options: .repeating)
                Text("Waiting for a location fix…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func recenter(on location: CLLocation) {
        camera = .region(MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }

    private func coordinatePill(for location: CLLocation) -> some View {
        Text(formatCoordinate(location))
            .font(.system(.caption2, design: .monospaced).weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .foregroundStyle(.primary)
    }

    private func formatCoordinate(_ location: CLLocation) -> String {
        String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude)
    }
}
