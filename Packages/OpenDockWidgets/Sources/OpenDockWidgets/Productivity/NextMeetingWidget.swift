import SwiftUI
import OpenDockKit

struct NextMeetingWidget: DockWidget {
    static let descriptor = WidgetDescriptor(id: "dev.opendock.next-meeting", name: "Next Meeting",
        summary: "Your next calendar event, a live countdown, and one-click joining.",
        symbol: "calendar.badge.clock", category: .productivity, supportedSizes: [.medium, .wide])
    func body(context: WidgetContext) -> some View { NextMeetingView(context: context) }
}

private struct NextMeetingView: View {
    @Environment(\.dockTheme) private var theme
    @State private var expanded = false
    @State private var requesting = false
    let context: WidgetContext
    private var service: MeetingService { context.services.meetings }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            Button { expanded.toggle() } label: {
                HStack(spacing: theme.scaled(8)) {
                    Image(systemName: "calendar.badge.clock").font(theme.statFont).foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: theme.scaled(2)) {
                        if let meeting = service.meetings.first {
                            Text(countdown(meeting, at: timeline.date)).font(theme.captionFont).foregroundStyle(.orange)
                            Text(meeting.title).font(theme.titleFont).lineLimit(1)
                            if context.size == .wide {
                                Text(meeting.start, format: .dateTime.hour().minute()).font(theme.captionFont).foregroundStyle(.secondary)
                            }
                        } else {
                            Text(service.access == .granted ? "All clear" : "Next Meeting").font(theme.titleFont)
                            Text(service.access == .granted ? "No events this week" : "Connect Calendar")
                                .font(theme.captionFont).foregroundStyle(.secondary).lineLimit(2)
                        }
                    }
                    Spacer(minLength: 0)
                }.padding(theme.contentPadding).frame(maxWidth: .infinity, maxHeight: .infinity).contentShape(Rectangle())
            }.buttonStyle(.plain)
        }
        .widgetPopover(isPresented: $expanded) {
            WidgetDetails(title: "Next Meeting", symbol: "calendar.badge.clock") {
                if service.access != .granted {
                    Text("Show timed events from the calendars on this Mac. All-day and declined events are excluded.").foregroundStyle(.secondary)
                    Button(service.access == .denied ? "Open Calendar Privacy" : "Allow Calendar Access") {
                        if service.access == .denied {
                            context.services.openURL(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
                        } else {
                            requesting = true
                            Task { await service.requestAccess(); requesting = false }
                        }
                    }.buttonStyle(.glassProminent).disabled(requesting)
                    if let error = service.error { Text(error).foregroundStyle(.secondary) }
                } else if service.meetings.isEmpty {
                    Text("No upcoming timed events in the next seven days.").foregroundStyle(.secondary)
                } else {
                    ForEach(service.meetings) { meeting in
                        VStack(alignment: .leading, spacing: theme.scaled(5)) {
                            Text(meeting.title).font(theme.titleFont)
                            Text(meeting.start, format: .dateTime.weekday().hour().minute()).foregroundStyle(.secondary)
                            Text(meeting.calendar).font(theme.captionFont).foregroundStyle(.secondary)
                            if !meeting.location.isEmpty && meeting.joinURL == nil {
                                Text(meeting.location).font(theme.captionFont).lineLimit(2)
                            }
                            if let url = meeting.joinURL {
                                Button("Join Meeting") { context.services.openURL(url); expanded = false }.buttonStyle(.glassProminent)
                            }
                        }
                        if meeting.id != service.meetings.last?.id { Divider() }
                    }
                }
                Button("Open Calendar") {
                    context.services.openApplication(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
                    expanded = false
                }.buttonStyle(.glass)
            }.environment(\.dockTheme, theme)
        }
        .task {
            while !Task.isCancelled {
                service.refresh()
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
            }
        }
    }
    private func countdown(_ meeting: Meeting, at date: Date) -> String {
        if meeting.end <= date { return "Just ended" }
        if meeting.start <= date { return "In progress" }
        let minutes = Int(ceil(meeting.start.timeIntervalSince(date) / 60))
        if minutes < 60 { return "In \(minutes) min" }
        if minutes < 1440 { return "In \(minutes / 60)h \(minutes % 60)m" }
        return meeting.start.formatted(.dateTime.weekday().hour().minute())
    }
}
