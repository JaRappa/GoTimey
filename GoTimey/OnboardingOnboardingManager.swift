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
final class OnboardingManager: NSObject, CLLocationManagerDelegate {

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

    override init() {
        super.init()
        // Assign delegate immediately so status callbacks are received.
        locationManager.delegate = self
    }

    // MARK: - CLLocationManagerDelegate

    // Called whenever the user responds to the location prompt,
    // or when the app returns from Settings.
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.locationStatus = status
        }
    }

    // MARK: - Request Permissions

    func requestLocationPermission() {
        // The delegate callback above will update locationStatus reliably.
        locationManager.requestWhenInUseAuthorization()
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
