//
//  UserPreferences.swift
//  GoTimey
//
//  Created by Jake on 2/17/26.
//

import Foundation

// MARK: - Transport Mode

enum TransportMode: String, CaseIterable, Identifiable {
    case car        = "car"
    case transit    = "transit"
    case bike       = "bike"
    case walk       = "walk"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .car:     return "Car"
        case .transit: return "Transit"
        case .bike:    return "Bike"
        case .walk:    return "Walk"
        }
    }

    var icon: String {
        switch self {
        case .car:     return "car.fill"
        case .transit: return "tram.fill"
        case .bike:    return "bicycle"
        case .walk:    return "figure.walk"
        }
    }

    var description: String {
        switch self {
        case .car:     return "Driving directions with live traffic"
        case .transit: return "Bus, subway, and train routes"
        case .bike:    return "Cycling routes and paths"
        case .walk:    return "Walking directions"
        }
    }
}

// MARK: - UserPreferences

@Observable
final class UserPreferences {

    // IDs of calendars the user has chosen to monitor
    var selectedCalendarIDs: Set<String> {
        get {
            let arr = UserDefaults.standard.stringArray(forKey: "selectedCalendarIDs") ?? []
            return Set(arr)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: "selectedCalendarIDs")
        }
    }

    var transportMode: TransportMode {
        get {
            let raw = UserDefaults.standard.string(forKey: "transportMode") ?? ""
            return TransportMode(rawValue: raw) ?? .car
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "transportMode")
        }
    }

    // Minutes before departure to start the live notification. Default: 30.
    var notificationLeadTime: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: "notificationLeadTime")
            return stored == 0 ? 30 : stored
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "notificationLeadTime")
        }
    }
}
