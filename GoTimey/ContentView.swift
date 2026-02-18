//
//  ContentView.swift
//  GoTimey
//
//  Created by Jake on 2/17/26.
//

import SwiftUI

struct ContentView: View {

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "figure.walk.departure")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)

                Text("You're all set!")
                    .font(.largeTitle.bold())

                Text("GoTimey is watching your calendar.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("GoTimey")
            .toolbar {
                // Handy during development — lets you re-run onboarding
                #if DEBUG
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset Onboarding") {
                        hasCompletedOnboarding = false
                    }
                    .font(.caption)
                }
                #endif
            }
        }
    }
}

#Preview {
    ContentView()
}
