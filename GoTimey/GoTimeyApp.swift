//
//  GoTimeyApp.swift
//  GoTimey
//
//  Created by Jake on 2/17/26.
//

import SwiftUI

@main
struct GoTimeyApp: App {

    // Mirrors the same UserDefaults key OnboardingManager writes to.
    // When onboarding completes, SwiftUI automatically swaps in ContentView.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

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
