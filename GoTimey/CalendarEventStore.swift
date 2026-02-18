//
//  CalendarEventStore.swift
//  GoTimey
//
//  Created by Jake on 2/17/26.
//

import Foundation
import EventKit

// MARK: - CalendarEvent (app model)

struct CalendarEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let calendarColor: CGColor
    let calendarTitle: String
    let isAllDay: Bool
}

// MARK: - CalendarEventStore

@Observable
final class CalendarEventStore {

    var upcomingEvents: [CalendarEvent] = []
    var isLoading: Bool = false

    private let store = EKEventStore()

    func load(preferences: UserPreferences) async {
        await MainActor.run { isLoading = true }

        let now   = Date()
        let end   = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now

        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        let rawEvents = store.events(matching: predicate)

        // Filter to only the user's selected calendars
        let selectedIDs = preferences.selectedCalendarIDs
        let filtered = rawEvents.filter { selectedIDs.contains($0.calendar.calendarIdentifier) }

        let mapped: [CalendarEvent] = filtered.map { ek in
            CalendarEvent(
                id:             ek.eventIdentifier,
                title:          ek.title ?? "Untitled Event",
                startDate:      ek.startDate,
                endDate:        ek.endDate,
                location:       ek.location.flatMap { $0.isEmpty ? nil : $0 },
                calendarColor:  ek.calendar.cgColor,
                calendarTitle:  ek.calendar.title,
                isAllDay:       ek.isAllDay
            )
        }

        await MainActor.run {
            upcomingEvents = mapped
            isLoading = false
        }
    }
}
