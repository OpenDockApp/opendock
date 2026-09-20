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

    @Test func archivingProducesAZipOnTheShelf() async throws {
        let first = try temporaryFile(named: "one.txt")
        let second = try temporaryFile(named: "two.txt")
        let archives = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "shelf-archives-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer {
            for url in [first, second].map({ $0.deletingLastPathComponent() }) + [archives] {
                try? FileManager.default.removeItem(at: url)
            }
        }

        let shelf = ShelfService(archiveFolder: archives)
        let items = try [first, second].map { try #require(shelf.item(for: $0)) }
        let archive = try await shelf.archive(items, named: "Shelf Items")

        let url = try #require(shelf.resolve(archive)?.url)
        #expect(url.pathExtension == "zip")
        #expect(archive.name == "Shelf Items.zip")
        let size = try #require(try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int)
        #expect(size > 0)
    }

    @Test func archivingLinksAloneFails() async throws {
        let shelf = ShelfService()
        let link = try #require(shelf.item(for: URL(string: "https://opendock.dev")!))
        await #expect(throws: ShelfService.ShelfError.self) {
            _ = try await shelf.archive([link], named: "Links")
        }
    }

    @Test func generatedArchivesAreDeletedButDroppedFilesAreNot() async throws {
        let file = try temporaryFile(named: "keep.txt")
        let archives = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
            .appending(path: "shelf-archives-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer {
            try? FileManager.default.removeItem(at: file.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: archives)
        }

        let shelf = ShelfService(archiveFolder: archives)
        let item = try #require(shelf.item(for: file))
        let archive = try await shelf.archive([item], named: "keep")
        let archiveURL = try #require(shelf.resolve(archive)?.url)

        shelf.deleteIfGenerated(archive)
        #expect(!FileManager.default.fileExists(atPath: archiveURL.path))

        shelf.deleteIfGenerated(item)
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test func itemsSurviveEncoding() throws {
        let item = ShelfItem(name: "Docs", kind: .link(URL(string: "https://opendock.dev")!))
        let data = try JSONEncoder().encode([item])
        let decoded = try JSONDecoder().decode([ShelfItem].self, from: data)
        #expect(decoded == [item])
    }
}
