//
//  DepartureActivityWidget.swift
//  GoTimeyWidgets
//
//  Lives in the Widget Extension target only.
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Lock Screen / Banner View

struct DepartureLockScreenView: View {

    let context: ActivityViewContext<DepartureAttributes>

    private var state: DepartureAttributes.ContentState { context.state }
    private var attrs: DepartureAttributes { context.attributes }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // MARK: Top row — headline
            HStack(spacing: 10) {
                Image(systemName: "clock.fill")
                    .font(.title3)
                Text(headlineText)
                    .font(.title3.bold())
                    .lineLimit(1)
                Spacer()
            }

            // MARK: Progress bar
            progressBar

            // MARK: Bottom row — arrive time + travel duration
            HStack {
                Image(systemName: "bag.fill")
                    .font(.caption)
                Text("Arrive at \(state.eventStartDate.formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline.bold())
                Spacer()
                Text(state.travelDuration)
                    .font(.subheadline.bold())
            }
        }
        .padding(16)
        .activityBackgroundTint(Color.black.opacity(0.75))
        .activitySystemActionForegroundColor(.white)
    }

    // MARK: - Headline

    private var headlineText: String {
        let now = Date()
        if now >= state.lastLeaveDate {
            return "Leave now!"
        } else if now >= state.idealLeaveDate {
            let mins = Int(state.lastLeaveDate.timeIntervalSince(now) / 60)
            return "Leave within \(mins) min"
        } else {
            let mins = Int(state.idealLeaveDate.timeIntervalSince(now) / 60)
            return "Go in \(mins) minutes"
        }
    }

    // MARK: - Progress Bar
    // The bar fills from idealLeaveDate toward lastLeaveDate.
    // Green = time remaining before ideal leave. Red = buffer window.

    private var progressBar: some View {
        let now = Date()
        let totalWindow = state.lastLeaveDate.timeIntervalSince(state.idealLeaveDate)
        let elapsed = now.timeIntervalSince(state.idealLeaveDate)
        let progress = totalWindow > 0 ? min(max(elapsed / totalWindow, 0), 1) : 1.0

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.green.opacity(0.3))
                    .frame(height: 12)

                // Filled portion (red = urgency)
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [.green, .yellow, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progress, height: 12)

                // Thumb indicator
                Circle()
                    .fill(.white)
                    .frame(width: 16, height: 16)
                    .shadow(radius: 2)
                    .offset(x: max(0, geo.size.width * progress - 8))
            }
        }
        .frame(height: 16)
    }
}

// MARK: - Dynamic Island Views

struct DepartureCompactLeading: View {
    let context: ActivityViewContext<DepartureAttributes>
    var body: some View {
        Image(systemName: context.attributes.transportIcon)
            .foregroundStyle(.tint)
    }
}

struct DepartureCompactTrailing: View {
    let context: ActivityViewContext<DepartureAttributes>
    var body: some View {
        let mins = Int(context.state.idealLeaveDate.timeIntervalSince(Date()) / 60)
        Text(mins > 0 ? "in \(mins)m" : "Now!")
            .font(.caption.bold())
            .foregroundStyle(mins > 5 ? .primary : .red)
    }
}

struct DepartureMinimal: View {
    let context: ActivityViewContext<DepartureAttributes>
    var body: some View {
        Image(systemName: "figure.walk.departure")
            .foregroundStyle(.tint)
    }
}

struct DepartureExpandedView: View {
    let context: ActivityViewContext<DepartureAttributes>

    var body: some View {
        DepartureLockScreenView(context: context)
    }
}

// MARK: - Widget Configuration

struct DepartureActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DepartureAttributes.self) { context in
            // Lock Screen / Banner
            DepartureLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: context.attributes.transportIcon)
                        Text(context.attributes.eventTitle)
                            .font(.caption.bold())
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    let mins = Int(context.state.idealLeaveDate.timeIntervalSince(Date()) / 60)
                    Text(mins > 0 ? "in \(mins) min" : "Leave now!")
                        .font(.caption.bold())
                        .foregroundStyle(mins > 5 ? .primary : .red)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    DepartureLockScreenView(context: context)
                        .padding(.horizontal, 8)
                }
            } compactLeading: {
                DepartureCompactLeading(context: context)
            } compactTrailing: {
                DepartureCompactTrailing(context: context)
            } minimal: {
                DepartureMinimal(context: context)
            }
        }
    }
}
