//
//  SettingsView.swift
//  GoTimey
//
//  Created by Jake on 2/17/26.
//

import SwiftUI
import EventKit

struct SettingsView: View {

    @Bindable var preferences: UserPreferences
    @Environment(\.dismiss) private var dismiss

    // Local state — same pattern as onboarding to avoid UserDefaults computed-property issues
    @State private var availableCalendars = [EKCalendar]()
    @State private var selectedIDs = Set<String>()
    @State private var selectedMode = TransportMode.car
    @State private var leadTime = 30

    private let eventStore = EKEventStore()
    private let minuteOptions = Array(1...180)

    var body: some View {
        NavigationStack {
            Form {
                calendarsSection
                transportSection
                leadTimeSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        preferences.selectedCalendarIDs  = selectedIDs
                        preferences.transportMode        = selectedMode
                        preferences.notificationLeadTime = leadTime
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                availableCalendars = eventStore.calendars(for: .event)
                selectedIDs        = preferences.selectedCalendarIDs
                selectedMode       = preferences.transportMode
                leadTime           = preferences.notificationLeadTime
            }
        }
    }

    // MARK: - Calendars Section

    @ViewBuilder
    private var calendarsSection: some View {
        Section {
            if availableCalendars.isEmpty {
                Text("No calendars available.\nCheck that calendar access is granted in Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(availableCalendars, id: \.calendarIdentifier) { cal in
                    HStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(cgColor: cal.cgColor))
                            .frame(width: 12, height: 12)
                        Text(cal.title)
                        Spacer()
                        if selectedIDs.contains(cal.calendarIdentifier) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                                .bold()
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedIDs.contains(cal.calendarIdentifier) {
                            selectedIDs.remove(cal.calendarIdentifier)
                        } else {
                            selectedIDs.insert(cal.calendarIdentifier)
                        }
                    }
                }
            }
        } header: {
            Text("Calendars")
        } footer: {
            Text("GoTimey will only show events from selected calendars.")
        }
    }

    // MARK: - Transport Section

    @ViewBuilder
    private var transportSection: some View {
        Section("Transport Mode") {
            ForEach(TransportMode.allCases) { mode in
                HStack(spacing: 14) {
                    Image(systemName: mode.icon)
                        .foregroundStyle(selectedMode == mode ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mode.label)
                        Text(mode.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if selectedMode == mode {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                            .bold()
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { selectedMode = mode }
            }
        }
    }

    // MARK: - Lead Time Section

    @ViewBuilder
    private var leadTimeSection: some View {
        Section {
            Picker("Heads-up time", selection: $leadTime) {
                ForEach(minuteOptions, id: \.self) { min in
                    Text(labelFor(minutes: min)).tag(min)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 140)
        } header: {
            Text("Notification Lead Time")
        } footer: {
            Text("GoTimey will start your departure notification \(labelFor(minutes: leadTime)) before you need to leave.")
        }
    }

    private func labelFor(minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else if minutes % 60 == 0 {
            return "\(minutes / 60) hr"
        } else {
            return "\(minutes / 60) hr \(minutes % 60) min"
        }
    }
}
