//
//  EventCard.swift
//  GoTimey
//
//  Created by Jake on 2/17/26.
//

import SwiftUI
import MapKit

struct EventCard: View {

    let event: CalendarEvent
    let transportMode: TransportMode

    @State private var timeUntilLeave: String? = nil
    @State private var travelTime: String?     = nil

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // MARK: Header row
            HStack(alignment: .top, spacing: 10) {
                // Calendar color pip
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(cgColor: event.calendarColor))
                    .frame(width: 4, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(.headline)
                        .lineLimit(2)

                    Text(event.calendarTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Time badge
                VStack(alignment: .trailing, spacing: 2) {
                    if event.isAllDay {
                        Text("All Day")
                            .font(.subheadline.bold())
                            .foregroundStyle(.tint)
                    } else {
                        Text(event.startDate, style: .time)
                            .font(.subheadline.bold())
                            .foregroundStyle(.tint)
                        Text(event.startDate, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            // MARK: Location row
            if let location = event.location {
                Button {
                    openInMaps(location: location)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundStyle(.tint)

                        Text(location)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Spacer()

                        Image(systemName: transportMode.icon)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let travel = travelTime {
                            Text(travel)
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)

                // Leave-by row
                if let leaveTime = timeUntilLeave {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.walk.departure")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Text("Leave by \(leaveTime)")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                    }
                }
            } else {
                // No location
                HStack(spacing: 8) {
                    Image(systemName: "location.slash")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text("No location")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .task {
            await fetchTravelTime()
        }
        .onReceive(timer) { _ in
            Task { await fetchTravelTime() }
        }
    }

    // MARK: - Maps Navigation

    private func openInMaps(location: String) {
        // Geocode the location string and open in Maps with the right transport type
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(location) { placemarks, _ in
            guard let placemark = placemarks?.first else {
                // Fallback: open Maps with a search query
                let query = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                if let url = URL(string: "maps://?q=\(query)") {
                    UIApplication.shared.open(url)
                }
                return
            }

            let mapItem = MKMapItem(placemark: MKPlacemark(placemark: placemark))
            mapItem.name = event.title

            let launchOptions: [String: Any] = [
                MKLaunchOptionsDirectionsModeKey: directionMode
            ]
            mapItem.openInMaps(launchOptions: launchOptions)
        }
    }

    private var directionMode: String {
        switch transportMode {
        case .car:     return MKLaunchOptionsDirectionsModeDriving
        case .transit: return MKLaunchOptionsDirectionsModeTransit
        case .bike:    return MKLaunchOptionsDirectionsModeDriving  // Maps uses driving for bike
        case .walk:    return MKLaunchOptionsDirectionsModeWalking
        }
    }

    // MARK: - Travel Time Estimation

    private func fetchTravelTime() async {
        guard let location = event.location, !event.isAllDay else { return }

        let geocoder = CLGeocoder()
        guard let placemarks = try? await geocoder.geocodeAddressString(location),
              let destination = placemarks.first?.location?.coordinate else { return }

        let request = MKDirections.Request()
        request.source      = MKMapItem.forCurrentLocation()
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = mkTransportType

        guard let directions = try? await MKDirections(request: request).calculate(),
              let route = directions.routes.first else { return }

        let travelSeconds = route.expectedTravelTime
        let leaveDate     = event.startDate.addingTimeInterval(-travelSeconds)

        await MainActor.run {
            travelTime     = formatDuration(travelSeconds)
            timeUntilLeave = leaveDate.formatted(date: .omitted, time: .shortened)
        }
    }

    private var mkTransportType: MKDirectionsTransportType {
        switch transportMode {
        case .car:              return .automobile
        case .transit:          return .transit
        case .bike, .walk:      return .walking
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let h = minutes / 60
            let m = minutes % 60
            return m == 0 ? "\(h) hr" : "\(h) hr \(m) min"
        }
    }
}
