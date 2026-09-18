import Foundation
import EventKit
import Observation

public struct Meeting: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let start: Date
    public let end: Date
    public let calendar: String
    public let location: String
    public let joinURL: URL?

    /// Only known conferencing HTTPS links become a Join action.
    public static func conferenceURL(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        return detector?.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .compactMap(\.url).first { url in
                guard url.scheme == "https", let host = url.host?.lowercased() else { return false }
                return ["zoom.us", "zoom.com", "meet.google.com", "teams.microsoft.com", "teams.live.com", "webex.com"]
                    .contains { host == $0 || host.hasSuffix("." + $0) }
            }
    }
}

@Observable
public final class MeetingService {
    public enum Access { case notDetermined, granted, denied }
    public static let shared = MeetingService()
    public private(set) var access: Access = .notDetermined
    public private(set) var meetings: [Meeting] = []
    public private(set) var error: String?
    private let store = EKEventStore()

    public init() {}

    public func requestAccess() async {
        do { _ = try await store.requestFullAccessToEvents(); error = nil }
        catch { self.error = "Calendar access could not be requested. Try again." }
        refresh()
    }

    public func refresh(now: Date = .now) {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: access = .granted
        case .notDetermined, .writeOnly: access = .notDetermined
        default: access = .denied
        }
        guard access == .granted else { meetings = []; return }
        let end = now.addingTimeInterval(7 * 86400)
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        meetings = store.events(matching: predicate)
            .filter { event in
                !event.isAllDay && event.status != .canceled && event.endDate > now &&
                !(event.attendees?.contains { $0.isCurrentUser && $0.participantStatus == .declined } ?? false)
            }
            .sorted { $0.startDate < $1.startDate }
            .prefix(4).map { event in
                Meeting(id: "\(event.eventIdentifier ?? event.calendarItemIdentifier)-\(event.startDate.timeIntervalSince1970)",
                        title: event.title?.isEmpty == false ? event.title : "Untitled event",
                        start: event.startDate, end: event.endDate, calendar: event.calendar.title,
                        location: event.location ?? "",
                        joinURL: Meeting.conferenceURL(in: [event.url?.absoluteString, event.location, event.notes].compactMap { $0 }.joined(separator: "\n")))
            }
    }
}
