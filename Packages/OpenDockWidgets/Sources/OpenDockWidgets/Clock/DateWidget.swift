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
        let theme = context.theme
        return TimelineView(.everyMinute) { timeline in
            VStack(spacing: 0) {
                Text(timeline.date, format: .dateTime.weekday(.abbreviated))
                    .font(.system(size: theme.scaled(8), weight: .bold))
                    .foregroundStyle(.red)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(timeline.date, format: .dateTime.day())
                    .font(.system(size: theme.scaled(24), weight: .semibold, design: .rounded))
                Text(timeline.date, format: .dateTime.month(.abbreviated))
                    .font(theme.captionFont)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
