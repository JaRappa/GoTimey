//
//  OnboardingView.swift
//  GoTimey
//
//  Created by Jake on 2/17/26.
//

import SwiftUI
import EventKit

struct OnboardingView: View {

    @State private var manager = OnboardingManager()
    @State private var preferences = UserPreferences()
    @State private var currentPage: Int = 0

    var body: some View {
        // Using a switch instead of TabView so each page is only
        // instantiated (and its .task fired) when it becomes active.
        // This prevents CalendarPickerPage from loading before permission is granted.
        ZStack {
            switch currentPage {
            case 0:
                WelcomePage(onContinue: { advance() })
                    .transition(pageTransition)
            case 1:
                PermissionsPage(manager: manager, onContinue: { advance() })
                    .transition(pageTransition)
            case 2:
                CalendarPickerPage(eventStore: manager.eventStore, preferences: preferences, onContinue: { advance() })
                    .transition(pageTransition)
            case 3:
                TransportModePage(preferences: preferences, onContinue: { advance() })
                    .transition(pageTransition)
            case 4:
                LeadTimePage(preferences: preferences, onContinue: {
                    manager.hasCompletedOnboarding = true
                })
                .transition(pageTransition)
            default:
                EmptyView()
            }
        }
        .animation(.easeInOut, value: currentPage)
        .task { await manager.refreshStatuses() }
    }

    private func advance() {
        currentPage += 1
    }

    private var pageTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing),
            removal: .move(edge: .leading)
        )
    }
}

// MARK: - Page 1: Welcome

private struct WelcomePage: View {

    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(.tint.opacity(0.15))
                    .frame(width: 130, height: 130)

                Image(systemName: "figure.walk.departure")
                    .font(.system(size: 60))
                    .foregroundStyle(.tint)
            }
            .padding(.bottom, 36)

            // Headline
            Text("Welcome to GoTimey")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .padding(.bottom, 16)

            // Sub-headline
            Text("Never be late again.\nGoTimey watches your calendar and tells you exactly when to head out the door — before you even think to check.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            // Feature highlights
            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(icon: "calendar",          color: .blue,   title: "Calendar Aware",        subtitle: "Reads your events automatically.")
                FeatureRow(icon: "location.fill",     color: .green,  title: "Real-Time Traffic",     subtitle: "Routes powered by Maps.")
                FeatureRow(icon: "bell.badge.fill",   color: .orange, title: "Smart Notifications",  subtitle: "Get nudged at just the right moment.")
            }
            .padding(.horizontal, 32)

            Spacer()

            Button(action: onContinue) {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.tint)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }
}

// MARK: - Page 2: Permissions

private struct PermissionsPage: View {

    @Bindable var manager: OnboardingManager
    let onContinue: () -> Void

    @State private var showingTerms: Bool   = false
    @State private var showingPrivacy: Bool = false
    @State private var agreedToTerms: Bool  = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("A Few Permissions")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .padding(.bottom, 12)

            Text("GoTimey needs access to a few things to work its magic.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 40)

            // Permission cards
            VStack(spacing: 16) {
                PermissionCard(
                    icon: "location.fill",
                    color: .green,
                    title: "Location",
                    description: "Calculates real-time travel time from where you are.",
                    status: locationStatusText,
                    statusColor: locationStatusColor,
                    onRequest: { manager.requestLocationPermission() }
                )

                PermissionCard(
                    icon: "calendar",
                    color: .blue,
                    title: "Calendars",
                    description: "Reads your upcoming events so we know where you need to be.",
                    status: calendarStatusText,
                    statusColor: calendarStatusColor,
                    onRequest: {
                        Task { await manager.requestCalendarPermission() }
                    }
                )

                PermissionCard(
                    icon: "bell.badge.fill",
                    color: .orange,
                    title: "Notifications",
                    description: "Alerts you when it's time to leave.",
                    status: notifStatusText,
                    statusColor: notifStatusColor,
                    onRequest: {
                        Task { await manager.requestNotificationPermission() }
                    }
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            // Terms & Privacy
            VStack(spacing: 8) {
                Toggle(isOn: $agreedToTerms) {
                    Group {
                        Text("I agree to the ")
                        + Text("Terms & Conditions")
                            .underline()
                            .foregroundStyle(.tint)
                        + Text(" and ")
                        + Text("Privacy Policy")
                            .underline()
                            .foregroundStyle(.tint)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .toggleStyle(.checkmark)
                .padding(.horizontal, 24)

                HStack(spacing: 24) {
                    Button("Terms & Conditions") { showingTerms = true }
                    Button("Privacy Policy")     { showingPrivacy = true }
                }
                .font(.footnote)
                .padding(.bottom, 8)
            }

            Button(action: onContinue) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canContinue ? Color.accentColor : Color.secondary.opacity(0.3))
                    .foregroundStyle(canContinue ? .white : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .animation(.default, value: canContinue)
            }
            .disabled(!canContinue)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .sheet(isPresented: $showingTerms) {
            LegalView(title: "Terms & Conditions", content: termsText)
        }
        .sheet(isPresented: $showingPrivacy) {
            LegalView(title: "Privacy Policy", content: privacyText)
        }
    }

    // The user must agree to terms to continue; permissions are encouraged but not blocked.
    private var canContinue: Bool { agreedToTerms }

    // MARK: Status helpers

    private var locationStatusText: String {
        switch manager.locationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return "Granted"
        case .denied, .restricted:                    return "Denied — tap to open Settings"
        default:                                       return "Tap to allow"
        }
    }

    private var locationStatusColor: Color {
        switch manager.locationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return .green
        case .denied, .restricted:                    return .red
        default:                                       return .secondary
        }
    }

    private var calendarStatusText: String {
        switch manager.calendarStatus {
        case .fullAccess, .writeOnly: return "Granted"
        case .denied, .restricted:   return "Denied — tap to open Settings"
        default:                      return "Tap to allow"
        }
    }

    private var calendarStatusColor: Color {
        switch manager.calendarStatus {
        case .fullAccess, .writeOnly: return .green
        case .denied, .restricted:   return .red
        default:                      return .secondary
        }
    }

    private var notifStatusText: String {
        switch manager.notificationStatus {
        case .authorized, .provisional: return "Granted"
        case .denied:                   return "Denied — tap to open Settings"
        default:                         return "Tap to allow"
        }
    }

    private var notifStatusColor: Color {
        switch manager.notificationStatus {
        case .authorized, .provisional: return .green
        case .denied:                   return .red
        default:                         return .secondary
        }
    }
}

// MARK: - Page 3: Calendar Picker

private struct CalendarPickerPage: View {

    let eventStore: EKEventStore
    @Bindable var preferences: UserPreferences
    let onContinue: () -> Void

    @State private var availableCalendars: [EKCalendar] = []
    // Local selection state — flushed to UserPreferences on Continue
    @State private var selectedIDs: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Choose Calendars")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .padding(.bottom, 12)

            Text("Select which calendars GoTimey should watch for upcoming events.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 32)

            if availableCalendars.isEmpty {
                ContentUnavailableView(
                    "No Calendars Found",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("Make sure calendar access was granted on the previous screen.")
                )
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(availableCalendars, id: \.calendarIdentifier) { calendar in
                            CalendarRow(
                                calendar: calendar,
                                isSelected: selectedIDs.contains(calendar.calendarIdentifier),
                                onToggle: {
                                    if selectedIDs.contains(calendar.calendarIdentifier) {
                                        selectedIDs.remove(calendar.calendarIdentifier)
                                    } else {
                                        selectedIDs.insert(calendar.calendarIdentifier)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }

            Spacer()

            Button {
                // Flush local selection into persistent preferences, then advance
                preferences.selectedCalendarIDs = selectedIDs
                onContinue()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canContinue ? Color.accentColor : Color.secondary.opacity(0.3))
                    .foregroundStyle(canContinue ? .white : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .animation(.default, value: canContinue)
            }
            .disabled(!canContinue)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .task {
            availableCalendars = eventStore.calendars(for: .event)
            // Pre-populate with any previously saved selection
            selectedIDs = preferences.selectedCalendarIDs
        }
    }

    private var canContinue: Bool { !selectedIDs.isEmpty }
}

// MARK: - Page 5: Notification Lead Time

private struct LeadTimePage: View {

    @Bindable var preferences: UserPreferences
    let onContinue: () -> Void

    // Wheel selection in minutes — local state flushed on Continue
    @State private var selectedMinutes: Int = 30

    // 1 min increments from 1–180 (1 to 3 hours)
    private let minuteOptions = Array(1...180)

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.tint.opacity(0.15))
                    .frame(width: 100, height: 100)
                Image(systemName: "bell.and.waves.left.and.right.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.tint)
            }
            .padding(.bottom, 28)

            Text("Heads-Up Time")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .padding(.bottom, 12)

            Text("How long before you need to leave should GoTimey start your live departure notification?")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 8)

            Spacer()

            // Summary label above the wheel
            Text(summaryText)
                .font(.title2.bold())
                .foregroundStyle(.tint)
                .contentTransition(.numericText())
                .animation(.default, value: selectedMinutes)
                .padding(.bottom, 8)

            // Wheel picker
            Picker("Lead time", selection: $selectedMinutes) {
                ForEach(minuteOptions, id: \.self) { minutes in
                    Text(labelFor(minutes: minutes))
                        .tag(minutes)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 180)
            .padding(.horizontal, 24)

            Text("Default is 30 minutes. You can always change this in Settings.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 8)

            Spacer()

            Button {
                preferences.notificationLeadTime = selectedMinutes
                onContinue()
            } label: {
                Text("Let's Go!")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.tint)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .onAppear {
            selectedMinutes = preferences.notificationLeadTime
        }
    }

    private var summaryText: String {
        if selectedMinutes < 60 {
            return "\(selectedMinutes) min before leaving"
        } else if selectedMinutes == 60 {
            return "1 hour before leaving"
        } else if selectedMinutes % 60 == 0 {
            return "\(selectedMinutes / 60) hours before leaving"
        } else {
            let h = selectedMinutes / 60
            let m = selectedMinutes % 60
            return "\(h) hr \(m) min before leaving"
        }
    }

    private func labelFor(minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else if minutes == 60 {
            return "1 hr"
        } else if minutes % 60 == 0 {
            return "\(minutes / 60) hr"
        } else {
            return "\(minutes / 60) hr \(minutes % 60) min"
        }
    }
}

// MARK: - Calendar Row

private struct CalendarRow: View {
    let calendar: EKCalendar
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(cgColor: calendar.cgColor))
                    .frame(width: 14, height: 14)

                Text(calendar.title)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Page 4: Transport Mode

private struct TransportModePage: View {

    @Bindable var preferences: UserPreferences
    let onContinue: () -> Void

    // Local selection state — flushed to UserPreferences on Continue
    @State private var selectedMode: TransportMode = .car

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("How Do You Get Around?")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .padding(.bottom, 12)

            Text("GoTimey will use this to calculate how long it'll take you to reach your events.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 32)

            VStack(spacing: 12) {
                ForEach(TransportMode.allCases) { mode in
                    TransportModeCard(
                        mode: mode,
                        isSelected: selectedMode == mode,
                        onSelect: { selectedMode = mode }
                    )
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            Button {
                // Flush local selection into persistent preferences, then advance
                preferences.transportMode = selectedMode
                onContinue()
            } label: {
                Text("Let's Go!")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.tint)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .onAppear {
            // Pre-populate with any previously saved preference
            selectedMode = preferences.transportMode
        }
    }
}

private struct TransportModeCard: View {
    let mode: TransportMode
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: mode.icon)
                        .font(.title3)
                        .foregroundStyle(isSelected ? .white : .secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.label)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(mode.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.default, value: isSelected)
    }
}

// MARK: - Reusable sub-views

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

private struct PermissionCard: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    let status: String
    let statusColor: Color
    let onRequest: () -> Void

    var body: some View {
        Button(action: onRequest) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    Text(description).font(.caption).foregroundStyle(.secondary)
                    Text(status).font(.caption.bold()).foregroundStyle(statusColor)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Legal Sheet

private struct LegalView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let content: String

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(content)
                    .font(.body)
                    .padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Checkmark Toggle Style

private struct CheckmarkToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(configuration.isOn ? Color.accentColor : .secondary)
                configuration.label
            }
        }
        .buttonStyle(.plain)
    }
}

private extension ToggleStyle where Self == CheckmarkToggleStyle {
    static var checkmark: CheckmarkToggleStyle { .init() }
}

// MARK: - Placeholder legal text

private let termsText = """
Terms & Conditions

Last updated: February 17, 2026

By using GoTimey, you agree to these terms. GoTimey is provided "as-is" without warranties of any kind. We are not liable for missed appointments or travel delays. You are responsible for verifying departure times independently.

[Replace this placeholder with your actual Terms & Conditions before shipping.]
"""

private let privacyText = """
Privacy Policy

Last updated: February 17, 2026

GoTimey collects location data, calendar events, and sends local notifications solely to provide departure reminders. No personal data is shared with third parties. All processing happens on your device.

[Replace this placeholder with your actual Privacy Policy before shipping.]
"""

// MARK: - Preview

#Preview {
    OnboardingView()
}
