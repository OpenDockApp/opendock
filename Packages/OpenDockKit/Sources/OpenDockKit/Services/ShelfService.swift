import AppKit
import QuickLookThumbnailing

/// One thing parked on a shelf: a file, a folder, or a link.
///
/// Files are stored as app-scoped security-scoped bookmarks, since the sandbox
/// extension a drop hands us dies with the process. Links are just the URL.
public struct ShelfItem: Identifiable, Hashable, Codable, Sendable {
    public enum Kind: Hashable, Codable, Sendable {
        case file(bookmark: Data)
        case link(URL)
    }

    public var id: UUID
    public var name: String
    public var kind: Kind
    public var addedAt: Date

    public init(id: UUID = UUID(), name: String, kind: Kind, addedAt: Date = .now) {
        self.id = id
        self.name = name
        self.kind = kind
        self.addedAt = addedAt
    }

    public var isLink: Bool {
        if case .link = kind { return true }
        return false
    }
}

/// Where an item points right now.
public struct ShelfResolution: Sendable {
    public let url: URL
    /// The file moved and the bookmark was minted again. Store it back on the item.
    public let refreshedBookmark: Data?
    /// The bookmark still resolves but nothing is there any more.
    public let isMissing: Bool
}

/// Turns dropped URLs into shelf items and resolves them back to usable URLs.
///
/// Access to a resolved file is started once and held for the lifetime of the
/// service, which lives as long as the app: shelves hold a handful of items, and
/// stopping access between clicks would break dragging an item back out.
public final class ShelfService {
    public static let shared = ShelfService()

    private var resolved: [UUID: URL] = [:]
    private var accessed: Set<URL> = []
    private var thumbnails: [UUID: NSImage] = [:]
    private let archiveFolderOverride: URL?

    /// `archiveFolder` names where zips go. Tests pass their own; the app uses
    /// its Application Support folder.
    public init(archiveFolder: URL? = nil) {
        archiveFolderOverride = archiveFolder
    }

    deinit {
        for url in accessed { url.stopAccessingSecurityScopedResource() }
    }

    // MARK: Adding

    /// A shelf item for a dropped or chosen URL, or nil if it cannot be kept.
    public func item(for url: URL) -> ShelfItem? {
        guard url.isFileURL else {
            guard url.scheme != nil, !url.absoluteString.isEmpty else { return nil }
            return ShelfItem(name: linkName(url), kind: .link(url))
        }
        guard let bookmark = makeBookmark(for: url) else { return nil }
        return ShelfItem(
            name: FileManager.default.displayName(atPath: url.path),
            kind: .file(bookmark: bookmark)
        )
    }

    private func makeBookmark(for url: URL) -> Data? {
        // A dropped URL already carries its extension; a bookmark from an open
        // panel needs the scope started while it is minted.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    private func linkName(_ url: URL) -> String {
        let last = url.lastPathComponent
        if let host = url.host(), !host.isEmpty {
            return last.isEmpty || last == "/" ? host : "\(host)/\(last)"
        }
        return url.absoluteString
    }

    // MARK: Resolving

    public func resolve(_ item: ShelfItem) -> ShelfResolution? {
        switch item.kind {
        case .link(let url):
            return ShelfResolution(url: url, refreshedBookmark: nil, isMissing: false)
        case .file(let bookmark):
            if let url = resolved[item.id] {
                return ShelfResolution(url: url, refreshedBookmark: nil, isMissing: !exists(url))
            }
            var stale = false
            guard let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) else { return nil }
            if url.startAccessingSecurityScopedResource() { accessed.insert(url) }
            resolved[item.id] = url
            return ShelfResolution(
                url: url,
                refreshedBookmark: stale ? makeBookmark(for: url) : nil,
                isMissing: !exists(url)
            )
        }
    }

    /// False when the file was thrown away or its volume is gone. A deleted file
    /// usually fails to resolve outright; a missing volume resolves but is not there.
    public func isAvailable(_ item: ShelfItem) -> Bool {
        guard let resolution = resolve(item) else { return false }
        return !resolution.isMissing
    }

    private func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    /// Applies any refreshed bookmarks so a moved file keeps working next launch.
    /// Returns nil when nothing changed, so callers can skip a write.
    public func refreshing(_ items: [ShelfItem]) -> [ShelfItem]? {
        var updated = items
        var changed = false
        for index in updated.indices {
            guard let refreshed = resolve(updated[index])?.refreshedBookmark else { continue }
            updated[index].kind = .file(bookmark: refreshed)
            changed = true
        }
        return changed ? updated : nil
    }

    // MARK: Using

    public func reveal(_ item: ShelfItem) {
        guard let url = resolve(item)?.url, !item.isLink else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Usable URLs for a selection, in order, skipping anything missing.
    public func urls(for items: [ShelfItem]) -> [URL] {
        items.compactMap { item in
            guard let resolution = resolve(item), !resolution.isMissing else { return nil }
            return resolution.url
        }
    }

    public func copyToPasteboard(_ items: [ShelfItem]) {
        let urls = urls(for: items)
        guard !urls.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(urls.map { $0 as NSURL })
    }

    // MARK: Archiving

    public enum ShelfError: Error {
        case nothingToArchive
        case archiveFailed
    }

    /// Where generated archives live. The sandbox grants read-only access to the
    /// files a user drops, so a zip cannot be written beside them; it goes in the
    /// app container and lands back on the shelf, ready to drag out or share.
    public var archiveFolder: URL {
        if let override = archiveFolderOverride { return override }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support
            .appending(path: Bundle.main.bundleIdentifier ?? "OpenDock", directoryHint: .isDirectory)
            .appending(path: "Archives", directoryHint: .isDirectory)
    }

    /// Zips the files in a selection and returns a shelf item for the archive.
    public func archive(_ items: [ShelfItem], named name: String) async throws -> ShelfItem {
        let sources = urls(for: items).filter(\.isFileURL)
        guard !sources.isEmpty else { throw ShelfError.nothingToArchive }
        let zip = try await Self.makeArchive(of: sources, named: name, in: archiveFolder)
        guard let item = item(for: zip) else { throw ShelfError.archiveFailed }
        return item
    }

    /// Copies everything into one staging folder and lets the file coordinator zip
    /// it, which is the only archiver that ships with the system.
    private nonisolated static func makeArchive(of sources: [URL], named name: String, in folder: URL) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            let manager = FileManager.default
            try manager.createDirectory(at: folder, withIntermediateDirectories: true)

            let root = manager.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
            let staging = root.appending(path: name, directoryHint: .isDirectory)
            try manager.createDirectory(at: staging, withIntermediateDirectories: true)
            defer { try? manager.removeItem(at: root) }
            for source in sources {
                try manager.copyItem(at: source, to: unique(staging.appending(path: source.lastPathComponent)))
            }

            var coordinationError: NSError?
            var copyError: (any Error)?
            var archive: URL?
            NSFileCoordinator().coordinate(
                readingItemAt: staging, options: [.forUploading], error: &coordinationError
            ) { zipped in
                let destination = unique(folder.appending(path: "\(name).zip"))
                do {
                    try manager.copyItem(at: zipped, to: destination)
                    archive = destination
                } catch {
                    copyError = error
                }
            }
            if let coordinationError { throw coordinationError }
            if let copyError { throw copyError }
            guard let archive else { throw ShelfError.archiveFailed }
            return archive
        }.value
    }

    /// `name`, `name 2`, `name 3`… so nothing is ever overwritten.
    private nonisolated static func unique(_ url: URL) -> URL {
        let manager = FileManager.default
        guard manager.fileExists(atPath: url.path) else { return url }
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let folder = url.deletingLastPathComponent()
        for suffix in 2...999 {
            var candidate = folder.appending(path: "\(base) \(suffix)")
            if !ext.isEmpty { candidate.appendPathExtension(ext) }
            if !manager.fileExists(atPath: candidate.path) { return candidate }
        }
        return url
    }

    /// Throws away an archive OpenDock made. Files the user dropped are left alone.
    public func deleteIfGenerated(_ item: ShelfItem) {
        // Resolved bookmarks come back with symlinks expanded (/private/var…),
        // so compare the real paths on both sides.
        let folder = archiveFolder.resolvingSymlinksInPath().path
        guard case .file = item.kind, let url = resolve(item)?.url,
              url.resolvingSymlinksInPath().path.hasPrefix(folder) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: Pictures

    /// Immediate icon for an item. The file icon, or the icon of the app that
    /// would open a link.
    public func icon(for item: ShelfItem) -> NSImage {
        guard let resolution = resolve(item) else { return Self.genericIcon }
        switch item.kind {
        case .file:
            guard !resolution.isMissing else { return Self.genericIcon }
            return NSWorkspace.shared.icon(forFile: resolution.url.path)
        case .link:
            guard let app = NSWorkspace.shared.urlForApplication(toOpen: resolution.url) else {
                return Self.genericIcon
            }
            return NSWorkspace.shared.icon(forFile: app.path)
        }
    }

    private static let genericIcon = NSWorkspace.shared.icon(for: .item)

    /// Quick Look preview for files, cached in memory. Nil means use `icon(for:)`.
    public func thumbnail(for item: ShelfItem, size: CGFloat, scale: CGFloat) async -> NSImage? {
        if let cached = thumbnails[item.id] { return cached }
        guard case .file = item.kind, let resolution = resolve(item), !resolution.isMissing else { return nil }
        let request = QLThumbnailGenerator.Request(
            fileAt: resolution.url,
            size: CGSize(width: size, height: size),
            scale: scale,
            representationTypes: .thumbnail
        )
        guard let representation = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
        else { return nil }
        let image = representation.nsImage
        thumbnails[item.id] = image
        return image
    }

    /// Drops cached state for items that are gone, so ids are not held forever.
    public func forget(_ item: ShelfItem) {
        if let url = resolved.removeValue(forKey: item.id), accessed.remove(url) != nil {
            url.stopAccessingSecurityScopedResource()
        }
        thumbnails.removeValue(forKey: item.id)
    }
}
