import SwiftUI
import OpenDockKit

struct ClockWidget: DockWidget {
    static let descriptor = WidgetDescriptor(
        id: "dev.opendock.clock",
        name: "Clock",
        summary: "Current time with the date underneath.",
        symbol: "clock",
        category: .time,
        supportedSizes: [.small, .medium],
        defaultSize: .medium
    )

    func body(context: WidgetContext) -> some View {
        ClockView(size: context.size)
    }
}

private struct ClockView: View {
    @Environment(\.dockTheme) private var theme
    let size: WidgetSize

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            VStack(alignment: .leading, spacing: 2) {
                Text(timeline.date, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute())
                    .font(size == .small
                          ? .system(size: 26, weight: .semibold, design: .rounded).monospacedDigit()
                          : .system(size: 40, weight: .semibold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(timeline.date, format: size == .small
                     ? .dateTime.weekday(.abbreviated).day()
                     : .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                    .font(size == .small ? theme.captionFont : theme.titleFont)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: size == .small ? .leading : .center)
            .padding(14)
        }
    }
}
