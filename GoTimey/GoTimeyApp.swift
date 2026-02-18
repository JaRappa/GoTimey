//
//  GoTimeyApp.swift
//  GoTimey
//
//  Created by Jake on 2/17/26.
//

import SwiftUI
import UserNotifications
import ActivityKit

@main
struct GoTimeyApp: App {

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingView()
            }
        }
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    private let preferences = UserPreferences()
    private let eventStore  = CalendarEventStore()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Fires when the user taps the notification, or when it arrives foregrounded
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        startActivityFromUserInfo(response.notification.request.content.userInfo)
        completionHandler()
    }

    // Fires when notification arrives while app is in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        startActivityFromUserInfo(notification.request.content.userInfo)
        // Suppress the banner since the Live Activity IS the UI
        completionHandler([])
    }

    private func startActivityFromUserInfo(_ userInfo: [AnyHashable: Any]) {
        guard
            let eventID = userInfo["eventID"] as? String,
            let modeRaw = userInfo["transportMode"] as? String,
            let mode    = TransportMode(rawValue: modeRaw)
        else { return }

        Task {
            await eventStore.load(preferences: preferences)
            guard let event = eventStore.upcomingEvents.first(where: { $0.id == eventID }) else { return }
            await DepartureActivityManager.shared.startActivity(
                for: event,
                transportMode: mode,
                preferences: preferences
            )
        }
    }
}

