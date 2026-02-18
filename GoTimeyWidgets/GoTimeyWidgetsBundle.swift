//
//  GoTimeyWidgetsBundle.swift
//  GoTimeyWidgets
//
//  Created by Jake on 2/17/26.
//

import WidgetKit
import SwiftUI

@main
struct GoTimeyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        GoTimeyWidgets()
        GoTimeyWidgetsControl()
        GoTimeyWidgetsLiveActivity()
    }
}
