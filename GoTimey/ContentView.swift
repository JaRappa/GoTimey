//
//  ContentView.swift
//  GoTimey
//
//  Created by Jake on 2/17/26.
//

import SwiftUI
import UserNotifications

struct ContentView: View {

    @State private var preferences = UserPreferences()
    @State private var eventStore  = CalendarEventStore()
    @State private var showSettings = false

    // Refreshes the event list every minute so started events drop off automatically
    private let refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            Group {
                if eventStore.isLoading {
                    ProgressView("Loading events…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if eventStore.upcomingEvents.isEmpty {
                    emptyState
                } else {
                    eventList
                }
            }
            .navigationTitle("GoTimey")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
                #if DEBUG
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        guard let event = eventStore.upcomingEvents.first else { return }
                        // Schedule a real notification 5 seconds out so you can background
                        // the app — the notification fires and starts the Live Activity
                        // exactly as the production flow does.
                        let content = UNMutableNotificationContent()
                        content.title = "GoTimey Test"
                        content.body  = "Starting Live Activity for \(event.title)"
                        content.sound = .default
                        content.userInfo = [
                            "eventID":       event.id,
                            "transportMode": preferences.transportMode.rawValue
                        ]
                        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
                        let request = UNNotificationRequest(
                            identifier: "debug-test",
                            content: content,
                            trigger: trigger
                        )
                        UNUserNotificationCenter.current().add(request)
                    } label: {
                        Label("Test", systemImage: "dot.radiowaves.left.and.right")
                    }
                    .disabled(eventStore.upcomingEvents.isEmpty)
                }
                #endif
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(preferences: preferences)
            }
            .task {
                await eventStore.load(preferences: preferences)
            }
            .onReceive(refreshTimer) { _ in
                Task { await eventStore.load(preferences: preferences) }
            }
            // Reload whenever the sheet is dismissed (user may have changed calendars)
            .onChange(of: showSettings) { _, isShowing in
                if !isShowing {
                    Task { await eventStore.load(preferences: preferences) }
                }
            }
            // Schedule a Live Activity for each upcoming event at the user's chosen lead time
            .onChange(of: eventStore.upcomingEvents) { _, events in
                for event in events {
                    DepartureActivityManager.shared.scheduleActivityStart(
                        for: event,
                        transportMode: preferences.transportMode,
                        preferences: preferences
                    )
                }
            }
        }
    }

    // MARK: - Event List

    private var eventList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(eventStore.upcomingEvents) { event in
                    EventCard(event: event, transportMode: preferences.transportMode)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "No Upcoming Events",
            systemImage: "calendar.badge.checkmark",
            description: Text("There are no events in your selected calendars for the next 7 days.")
        )
    }
}

#Preview {
    ContentView()
}
