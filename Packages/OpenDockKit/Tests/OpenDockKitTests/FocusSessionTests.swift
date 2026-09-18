import Foundation
import Testing
@testable import OpenDockKit

struct FocusSessionTests {
    @Test func pauseAndResumeRetainsRemainingTime() {
        var session = FocusSession()
        let start = Date(timeIntervalSince1970: 1000)
        session.toggle(at: start)
        session.toggle(at: start.addingTimeInterval(60))
        #expect(session.remaining == 1440)
        #expect(session.secondsLeft(at: start.addingTimeInterval(600)) == 1440)
        session.toggle(at: start.addingTimeInterval(600))
        #expect(session.secondsLeft(at: start.addingTimeInterval(660)) == 1380)
    }
    @Test func resetClearsRunningDeadlineAndPersists() throws {
        var session = FocusSession()
        let start = Date(timeIntervalSince1970: 1000)
        session.reset(minutes: 15)
        session.toggle(at: start)
        session.reset(minutes: Int(session.duration / 60), phase: session.phase)
        let restored = try JSONDecoder().decode(FocusSession.self, from: JSONEncoder().encode(session))
        #expect(restored.deadline == nil)
        #expect(restored.secondsLeft(at: start.addingTimeInterval(600)) == 900)
        #expect(restored.progress(at: start.addingTimeInterval(600)) == 0)
        #expect(restored.completed == 0)
        session.toggle(at: start.addingTimeInterval(600))
        #expect(session.secondsLeft(at: start.addingTimeInterval(610)) == 890)
    }

    @Test func sleepingPastDeadlineCompletesOnlyOnce() throws {
        var session = FocusSession()
        let start = Date(timeIntervalSince1970: 1000)
        session.toggle(at: start)
        let restored = try JSONDecoder().decode(FocusSession.self, from: JSONEncoder().encode(session))
        session = restored
        let completed = session.finishIfNeeded(at: start.addingTimeInterval(3600))
        #expect(completed)
        let repeated = session.finishIfNeeded(at: start.addingTimeInterval(3601))
        #expect(!repeated)
        #expect(session.completed == 1)
        #expect(session.progress(at: start.addingTimeInterval(3601)) == 1)
        session.reset(minutes: 5, phase: .rest)
        session.toggle(at: start)
        let breakCompleted = session.finishIfNeeded(at: start.addingTimeInterval(301))
        #expect(breakCompleted)
        #expect(session.completed == 1)
    }
}
