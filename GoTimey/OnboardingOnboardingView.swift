//
//  OnboardingView.swift
//  GoTimey
//
//  Created by Jake on 2/17/26.
//

import SwiftUI

struct OnboardingView: View {

    @State private var manager = OnboardingManager()
    @State private var currentPage: Int = 0

    var body: some View {
        TabView(selection: $currentPage) {
            WelcomePage(onContinue: { currentPage = 1 })
                .tag(0)

            PermissionsPage(manager: manager, onContinue: {
                manager.hasCompletedOnboarding = true
            })
            .tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.easeInOut, value: currentPage)
        .task { await manager.refreshStatuses() }
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
