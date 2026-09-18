import OpenDockKit

/// First-party native widgets. Add new widgets here so the app picks them up.
public enum OpenDockWidgets {
    public static func registerAll(in registry: WidgetRegistry = .shared) {
        registry.register(ClockWidget.self)
        registry.register(DateWidget.self)
        registry.register(LauncherWidget.self)
        registry.register(CPUWidget.self)
        registry.register(FocusTimerWidget.self)
        registry.register(NextMeetingWidget.self)
        registry.register(BatteryWidget.self)
    }
}
