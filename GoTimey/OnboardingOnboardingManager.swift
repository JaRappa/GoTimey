//
//  OnboardingManager.swift
//  GoTimey
//
//  Created by Jake on 2/17/26.
//

import SwiftUI
import CoreLocation
import EventKit
import UserNotifications

@Observable
final class OnboardingManager {

    // Persists whether the user has completed onboarding.
    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    // MARK: - Permission State

    var locationStatus: CLAuthorizationStatus = .notDetermined
    var calendarStatus: EKAuthorizationStatus = .notDetermined
    var notificationStatus: UNAuthorizationStatus = .notDetermined

    var allPermissionsGranted: Bool {
        let locationOK = locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways
        let calendarOK = calendarStatus == .fullAccess || calendarStatus == .writeOnly
        let notifOK    = notificationStatus == .authorized || notificationStatus == .provisional
        return locationOK && calendarOK && notifOK
    }

    // MARK: - Private helpers

    private let locationManager = CLLocationManager()
    private let eventStore      = EKEventStore()

    // MARK: - Request Permissions

    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
        // Poll after a short delay so the UI reflects any immediate resolution.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            locationStatus = locationManager.authorizationStatus
        }
    }

    func requestCalendarPermission() async {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            await MainActor.run {
                calendarStatus = granted ? .fullAccess : .denied
            }
        } catch {
            await MainActor.run { calendarStatus = .denied }
        }
    }

    func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            let settings = await center.notificationSettings()
            await MainActor.run {
                notificationStatus = granted ? .authorized : settings.authorizationStatus
            }
        } catch {
            await MainActor.run { notificationStatus = .denied }
        }
    }

    // MARK: - Refresh current statuses (call on appear)

    func refreshStatuses() async {
        locationStatus = locationManager.authorizationStatus

        calendarStatus = EKEventStore.authorizationStatus(for: .event)

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run { notificationStatus = settings.authorizationStatus }
    }
}
