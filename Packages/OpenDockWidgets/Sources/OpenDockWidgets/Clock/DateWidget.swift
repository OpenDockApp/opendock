import SwiftUI
import OpenDockKit

struct DateWidget: DockWidget {
    static let descriptor = WidgetDescriptor(
        id: "dev.opendock.date",
        name: "Date",
        summary: "Big day number, like a calendar page.",
        symbol: "calendar",
        category: .time,
        supportedSizes: [.small]
    )

    func body(context: WidgetContext) -> some View {
        TimelineView(.everyMinute) { timeline in
            VStack(spacing: 0) {
                Text(timeline.date, format: .dateTime.weekday(.wide))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.red)
                    .textCase(.uppercase)
                Text(timeline.date, format: .dateTime.day())
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                Text(timeline.date, format: .dateTime.month(.abbreviated))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
