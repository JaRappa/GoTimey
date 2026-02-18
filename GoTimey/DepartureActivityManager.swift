//
//  DepartureActivityManager.swift
//  GoTimey
//
//  Lives in the main app target only.
//

import ActivityKit
import CoreLocation
import MapKit
import UserNotifications
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
            scheduleUpdates(for: event, mode: transportMode)        } catch {
            print("GoTimey: Failed to start Live Activity — \(error)")
        }
    }

    // MARK: - Update

    private func scheduleUpdates(for event: CalendarEvent, mode: TransportMode, startingAt startDate: Date = Date()) {
        updateTask?.cancel()
        updateTask = Task {
            // Wait until the alert time before beginning live updates
            let delay = startDate.timeIntervalSince(Date())
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5 * 60))
                guard !Task.isCancelled else { break }

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

    /// Starts the Live Activity immediately but schedules the alert
    /// (banner + sound) to appear at the right time via alertConfiguration.
    /// This way the activity is registered with the system immediately
    /// and doesn't require the app to be running when it's time to notify.
    func scheduleActivityStart(
        for event: CalendarEvent,
        transportMode: TransportMode,
        preferences: UserPreferences
    ) {
        guard let location = event.location else { return }

        Task {
            guard let (travelSeconds, _) = await fetchTravelTime(to: location, mode: transportMode) else { return }

            let buffer   = max(travelSeconds * 0.10, 5 * 60)
            let lastLeave = event.startDate.addingTimeInterval(-(travelSeconds - buffer))
            let leadTime  = TimeInterval(preferences.notificationLeadTime * 60)
            let alertDate = lastLeave.addingTimeInterval(-leadTime)

            // Only schedule if the alert time is in the future
            guard alertDate > Date() else { return }

            let idealLeave = event.startDate.addingTimeInterval(-travelSeconds)

            let attributes = DepartureAttributes(
                eventTitle:     event.title,
                eventLocation:  location,
                transportIcon:  transportMode.icon
            )

            let state = DepartureAttributes.ContentState(
                idealLeaveDate: idealLeave,
                lastLeaveDate:  lastLeave,
                eventStartDate: event.startDate,
                travelDuration: formatDuration(travelSeconds)
            )

            let alertConfig = AlertConfiguration(
                title: "Time to leave for \(event.title)",
                body:  "Leave by \(lastLeave.formatted(date: .omitted, time: .shortened)) — \(formatDuration(travelSeconds)) away.",
                sound: .default
            )

            // AlertConfiguration makes the Live Activity banner appear and play
            // a sound when update is called — even if the app is not running.

            do {
                // End any previous activity for this event first
                await endCurrentActivity()

                let activity = try Activity.request(
                    attributes: attributes,
                    content: .init(state: state, staleDate: alertDate.addingTimeInterval(5 * 60)),
                    pushType: nil
                )
                currentActivity = activity

                // Update with the alert — this triggers the banner + sound
                // at delivery time even if the app is not running.
                let alertContent = ActivityContent(
                    state: state,
                    staleDate: alertDate.addingTimeInterval(5 * 60),
                    relevanceScore: 100
                )
                await activity.update(alertContent, alertConfiguration: alertConfig)

                print("GoTimey: Live Activity scheduled, alert at \(alertDate)")

                // Begin live travel time updates starting from alertDate
                scheduleUpdates(for: event, mode: transportMode, startingAt: alertDate)

            } catch {
                print("GoTimey: Failed to schedule Live Activity — \(error)")
            }
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
