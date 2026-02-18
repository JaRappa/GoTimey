//
//  DepartureAttributes.swift
//  GoTimey
//
//  Add this file to BOTH the main app target and the widget extension target.
//

import ActivityKit
import Foundation

struct DepartureAttributes: ActivityAttributes {

    // Static info — set once when the activity starts, never changes
    let eventTitle: String
    let eventLocation: String
    let transportIcon: String   // SF Symbol name

    // Dynamic info — updated as travel time changes
    public struct ContentState: Codable, Hashable {
        /// The ideal time to leave (current travel time + buffer)
        var idealLeaveDate: Date
        /// The absolute latest you can leave and still arrive on time
        var lastLeaveDate: Date
        /// When the event actually starts
        var eventStartDate: Date
        /// Human-readable travel duration e.g. "24 min"
        var travelDuration: String
    }
}
