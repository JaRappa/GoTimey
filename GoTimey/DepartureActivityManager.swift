//
//  DepartureActivityManager.swift
//  GoTimey
//
//  Lives in the main app target only.
//

import ActivityKit
import CoreLocation
import MapKit
import Foundation

@Observable
final class DepartureActivityManager {

    static let shared = DepartureActivityManager()

    // Currently running activity, if any
    private(set) var currentActivity: Activity<DepartureAttributes>?

    // Background task handle so updates keep running when app is backgrounded
    private var updateTask: Task<Void, Never>?

    private init() {}

    // MARK: - Start

    /// Call this when it's time to begin the live activity for an upcoming event.
    func startActivity(
        for event: CalendarEvent,
        transportMode: TransportMode,
        preferences: UserPreferences
    ) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // End any existing activity first
        await endCurrentActivity()

        guard let location = event.location else { return }

        // Fetch initial travel time
        guard let (travelSeconds, _) = await fetchTravelTime(to: location, mode: transportMode) else { return }

        let now = Date()
        let idealLeave = event.startDate.addingTimeInterval(-travelSeconds)
        // Last possible leave gives a 10% buffer on top of travel time (minimum 5 min)
        let buffer = max(travelSeconds * 0.10, 5 * 60)
        let lastLeave = event.startDate.addingTimeInterval(-(travelSeconds - buffer))

        let attributes = DepartureAttributes(
            eventTitle: event.title,
            eventLocation: location,
            transportIcon: transportMode.icon
        )

        let state = DepartureAttributes.ContentState(
            idealLeaveDate: idealLeave,
            lastLeaveDate: lastLeave,
            eventStartDate: event.startDate,
            travelDuration: formatDuration(travelSeconds)
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: now.addingTimeInterval(5 * 60))
            )
            currentActivity = activity

            // Start a background loop that refreshes travel time every 5 minutes
            scheduleUpdates(for: event, mode: transportMode)
        } catch {
            print("GoTimey: Failed to start Live Activity — \(error)")
        }
    }

    // MARK: - Update

    private func scheduleUpdates(for event: CalendarEvent, mode: TransportMode) {
        updateTask?.cancel()
        updateTask = Task {
            while !Task.isCancelled {
                // Refresh every 5 minutes or when the event is imminent
                try? await Task.sleep(for: .seconds(5 * 60))
                guard !Task.isCancelled else { break }

                // Stop updating once the event has started
                if Date() >= event.startDate {
                    await endCurrentActivity()
                    break
                }

                await updateActivity(for: event, mode: mode)
            }
        }
    }

    private func updateActivity(for event: CalendarEvent, mode: TransportMode) async {
        guard let activity = currentActivity,
              let location = event.location else { return }

        guard let (travelSeconds, _) = await fetchTravelTime(to: location, mode: mode) else { return }

        let idealLeave = event.startDate.addingTimeInterval(-travelSeconds)
        let buffer = max(travelSeconds * 0.10, 5 * 60)
        let lastLeave = event.startDate.addingTimeInterval(-(travelSeconds - buffer))

        let newState = DepartureAttributes.ContentState(
            idealLeaveDate: idealLeave,
            lastLeaveDate: lastLeave,
            eventStartDate: event.startDate,
            travelDuration: formatDuration(travelSeconds)
        )

        await activity.update(
            .init(state: newState, staleDate: Date().addingTimeInterval(5 * 60))
        )
    }

    // MARK: - End

    func endCurrentActivity() async {
        updateTask?.cancel()
        updateTask = nil

        guard let activity = currentActivity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        currentActivity = nil
    }

    // MARK: - Scheduling helper

    /// Called by CalendarEventStore/NotificationScheduler to start activities
    /// at the right time based on the user's lead time preference.
    func scheduleActivityStart(
        for event: CalendarEvent,
        transportMode: TransportMode,
        preferences: UserPreferences
    ) {
        let leadTime = TimeInterval(preferences.notificationLeadTime * 60)
        let triggerDate = event.startDate.addingTimeInterval(-leadTime)
        let delay = triggerDate.timeIntervalSince(Date())

        guard delay > 0 else { return }

        Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await startActivity(for: event, transportMode: transportMode, preferences: preferences)
        }
    }

    // MARK: - Travel Time

    private func fetchTravelTime(
        to locationString: String,
        mode: TransportMode
    ) async -> (TimeInterval, CLLocationCoordinate2D)? {
        let geocoder = CLGeocoder()
        guard let placemarks = try? await geocoder.geocodeAddressString(locationString),
              let coord = placemarks.first?.location?.coordinate else { return nil }

        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: coord))
        request.transportType = mkTransportType(for: mode)

        guard let result = try? await MKDirections(request: request).calculate(),
              let route = result.routes.first else { return nil }

        return (route.expectedTravelTime, coord)
    }

    private func mkTransportType(for mode: TransportMode) -> MKDirectionsTransportType {
        switch mode {
        case .car:          return .automobile
        case .transit:      return .transit
        case .bike, .walk:  return .walking
        }
    }

    // MARK: - Formatting

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
