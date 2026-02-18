//
//  ContentView.swift
//  GoTimey
//
//  Created by Jake on 2/17/26.
//

import SwiftUI

struct ContentView: View {

    @State private var preferences = UserPreferences()
    @State private var eventStore  = CalendarEventStore()
    @State private var showSettings = false

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
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(preferences: preferences)
            }
            .task {
                await eventStore.load(preferences: preferences)
            }
            // Reload whenever the sheet is dismissed (user may have changed calendars)
            .onChange(of: showSettings) { _, isShowing in
                if !isShowing {
                    Task { await eventStore.load(preferences: preferences) }
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
