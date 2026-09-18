import Foundation

/// A deadline, rather than tick counting, keeps sessions accurate through sleep and auto-hide.
public struct FocusSession: Codable, Equatable, Sendable {
    public enum Phase: String, Codable, Sendable { case focus, rest }
    public var phase: Phase = .focus
    public var duration: TimeInterval = 25 * 60
    public var remaining: TimeInterval = 25 * 60
    public var deadline: Date?
    public var completed: Int = 0

    public init() {}
    public func secondsLeft(at date: Date) -> TimeInterval {
        max(0, deadline.map { $0.timeIntervalSince(date) } ?? remaining)
    }
    public func progress(at date: Date) -> Double {
        min(1, max(0, 1 - secondsLeft(at: date) / duration))
    }
    public mutating func toggle(at date: Date) {
        if deadline != nil {
            remaining = secondsLeft(at: date)
            deadline = nil
        } else {
            deadline = date.addingTimeInterval(remaining)
        }
    }
    @discardableResult
    public mutating func finishIfNeeded(at date: Date) -> Bool {
        guard let deadline, date >= deadline else { return false }
        if phase == .focus { completed += 1 }
        self.deadline = nil
        remaining = 0
        return true
    }
    public mutating func reset(minutes: Int, phase: Phase = .focus) {
        self.phase = phase
        duration = TimeInterval(max(1, minutes) * 60)
        remaining = duration
        deadline = nil
    }
}
