import SwiftUI
import OpenDockKit

struct FocusTimerWidget: DockWidget {
    static let descriptor = WidgetDescriptor(
        id: "dev.opendock.focus-timer", name: "Focus Timer",
        summary: "A quiet orbit for deep work, with focus sessions and restorative breaks.",
        symbol: "scope", category: .productivity,
        supportedSizes: [.medium, .wide], defaultSize: .medium
    )
    func body(context: WidgetContext) -> some View { FocusTimerView(context: context) }
}

private struct FocusTimerView: View {
    @Environment(\.dockTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var session = FocusSession()
    @State private var showDetails = false
    @State private var loaded = false
    let context: WidgetContext

    private var tint: Color { session.phase == .focus ? .indigo : .mint }
    private var finished: Bool { session.remaining == 0 && session.deadline == nil }
    private var title: String { finished ? "Well done" : session.phase == .focus ? "Deep focus" : "Breathe" }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            HStack(spacing: theme.scaled(7)) {
                Button { showDetails.toggle() } label: {
                    ZStack {
                        Circle().stroke(tint.opacity(0.15), lineWidth: theme.scaled(3))
                        Circle().trim(from: 0, to: session.progress(at: timeline.date))
                            .stroke(tint.gradient, style: StrokeStyle(lineWidth: theme.scaled(3), lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Image(systemName: finished ? "checkmark" : session.phase == .focus ? "scope" : "leaf.fill")
                            .font(theme.statFont).foregroundStyle(tint)
                        Circle().fill(tint).frame(width: theme.scaled(5), height: theme.scaled(5))
                            .offset(y: -theme.scaled(19))
                            .rotationEffect(.degrees(session.progress(at: timeline.date) * 360))
                    }
                    .frame(width: theme.scaled(38), height: theme.scaled(38))
                    .animation(reduceMotion ? nil : .linear(duration: 1), value: session.progress(at: timeline.date))
                }.buttonStyle(.plain).help("Focus timer options").accessibilityLabel("Focus timer options")
                Button { toggle() } label: {
                    VStack(alignment: .leading, spacing: theme.scaled(1)) {
                        Text(title).font(theme.captionFont).foregroundStyle(.secondary)
                        Text(timeLabel(at: timeline.date)).font(theme.statFont).contentTransition(.numericText())
                        if context.size == .wide {
                            Text("\(session.completed) sessions · \(finished ? "Take a break" : session.deadline == nil ? "Tap to start" : "Tap to pause")")
                                .font(theme.captionFont).foregroundStyle(.secondary)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .accessibilityLabel("\(title), \(timeLabel(at: timeline.date)). \(session.deadline == nil ? "Start" : "Pause")")
            }
            .padding(theme.contentPadding)
            .onChange(of: timeline.date) { _, date in
                if loaded && session.finishIfNeeded(at: date) { save() }
            }
        }
        .popover(isPresented: $showDetails) {
            WidgetDetails(title: "Make room for focus", symbol: "scope") {
                Text(finished ? "Session complete. Take a moment before your next one." : "One thing at a time. Everything else can wait.")
                    .foregroundStyle(.secondary)
                HStack {
                    ForEach([15, 25, 50], id: \.self) { minutes in
                        Button("\(minutes) min") { session.reset(minutes: minutes); save() }
                    }
                }.buttonStyle(.glass)
                HStack {
                    Button(session.deadline == nil ? "Start" : "Pause") { toggle() }.buttonStyle(.glassProminent)
                    Button("Break") { session.reset(minutes: 5, phase: .rest); save() }.buttonStyle(.glass)
                    Button("Reset") {
                        session.reset(minutes: Int(session.duration / 60), phase: session.phase); save()
                    }.buttonStyle(.glass)
                }
                Label("\(session.completed) focus sessions completed", systemImage: "checkmark.circle")
                    .foregroundStyle(tint)
            }.environment(\.dockTheme, theme)
        }
        .onAppear {
            guard !loaded else { return }
            session = context.services.storage.get("focus.session", instance: context.instanceID, as: FocusSession.self) ?? FocusSession()
            loaded = true
            if session.finishIfNeeded(at: .now) { save() }
        }
    }
    private func timeLabel(at date: Date) -> String {
        let seconds = Int(ceil(session.secondsLeft(at: date)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
    private func toggle() {
        session.finishIfNeeded(at: .now)
        if finished { session.reset(minutes: session.phase == .focus ? 5 : 25, phase: session.phase == .focus ? .rest : .focus) }
        session.toggle(at: .now); save()
    }
    private func save() { context.services.storage.set(session, for: "focus.session", instance: context.instanceID) }
}
