import Foundation
import Testing
@testable import OpenDockKit

@Suite struct ShelfTests {
    private func temporaryFile(named name: String) throws -> URL {
        let directory = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "shelf-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appending(path: name)
        try Data("shelf".utf8).write(to: file)
        return file
    }

    @Test func linksKeepTheirURL() throws {
        let shelf = ShelfService()
        let item = try #require(shelf.item(for: URL(string: "https://opendock.dev/docs")!))
        #expect(item.isLink)
        #expect(item.name == "opendock.dev/docs")
        #expect(shelf.resolve(item)?.url.absoluteString == "https://opendock.dev/docs")
    }

    @Test func bareHostLinksAreNamedByHost() throws {
        let shelf = ShelfService()
        let item = try #require(shelf.item(for: URL(string: "https://opendock.dev")!))
        #expect(item.name == "opendock.dev")
    }

    @Test func schemelessURLsAreRejected() {
        #expect(ShelfService().item(for: URL(string: "opendock.dev")!) == nil)
    }

    @Test func filesResolveBackToTheirURL() throws {
        let file = try temporaryFile(named: "notes.txt")
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }

        let shelf = ShelfService()
        let item = try #require(shelf.item(for: file))
        #expect(!item.isLink)
        #expect(item.name == "notes.txt")

        let resolution = try #require(shelf.resolve(item))
        #expect(resolution.url.standardizedFileURL == file.standardizedFileURL)
        #expect(!resolution.isMissing)
    }

    @Test func deletedFilesAreUnavailable() throws {
        let file = try temporaryFile(named: "gone.txt")
        let shelf = ShelfService()
        let item = try #require(shelf.item(for: file))
        #expect(shelf.isAvailable(item))
        try FileManager.default.removeItem(at: file.deletingLastPathComponent())
        #expect(!shelf.isAvailable(item))
    }

    @Test func refreshingReportsNoChangeForFreshItems() throws {
        let file = try temporaryFile(named: "fresh.txt")
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let shelf = ShelfService()
        let item = try #require(shelf.item(for: file))
        #expect(shelf.refreshing([item]) == nil)
    }

    @Test func itemsSurviveEncoding() throws {
        let item = ShelfItem(name: "Docs", kind: .link(URL(string: "https://opendock.dev")!))
        let data = try JSONEncoder().encode([item])
        let decoded = try JSONDecoder().decode([ShelfItem].self, from: data)
        #expect(decoded == [item])
    }
}
