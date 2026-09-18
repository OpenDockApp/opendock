import Foundation
import Testing
@testable import OpenDockKit

struct MeetingTests {
    @Test func conferenceLinksUseExactHosts() {
        #expect(Meeting.conferenceURL(in: "Join https://meet.google.com/abc-defg-hij")?.host == "meet.google.com")
        #expect(Meeting.conferenceURL(in: "https://company.zoom.us/j/123")?.host == "company.zoom.us")
        #expect(Meeting.conferenceURL(in: "https://zoom.us.attacker.example/j/123") == nil)
        #expect(Meeting.conferenceURL(in: "http://meet.google.com/abc") == nil)
        #expect(Meeting.conferenceURL(in: "https://example.com/agenda") == nil)
    }
}
