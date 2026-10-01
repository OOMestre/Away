import Foundation

/// Full copy of the Dock domain taken before Away changed anything.
public struct DockBackup: Codable, Equatable, Sendable {
    public let date: Date
    public let values: [String: PropertyListValue]

    public init(date: Date, values: [String: PropertyListValue]) {
        self.date = date
        self.values = values
    }
}

/// What one `apply` replaced, so it can be undone without touching anything else.
public struct DockUndoEntry: Codable, Equatable, Sendable {
    public let date: Date
    /// Previous values of keys that existed before the change.
    public let previousValues: [String: PropertyListValue]
    /// Keys that did not exist before the change and must be removed again.
    public let absentKeys: [String]

    public init(date: Date, previousValues: [String: PropertyListValue], absentKeys: [String]) {
        self.date = date
        self.previousValues = previousValues
        self.absentKeys = absentKeys
    }
}

public protocol DockBackupStore: Sendable {
    func loadOriginal() throws -> DockBackup?
    func saveOriginal(_ backup: DockBackup) throws
    func loadHistory() throws -> [DockUndoEntry]
    func saveHistory(_ history: [DockUndoEntry]) throws
}

/// Stores backups as property lists in Application Support.
public final class FileDockBackupStore: DockBackupStore, @unchecked Sendable {
    private let directory: URL
    private let fileManager = FileManager.default

    public init(directory: URL) {
        self.directory = directory
    }

    /// `~/Library/Application Support/Away/Backups/Dock`
    public static func applicationSupport() throws -> FileDockBackupStore {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        return FileDockBackupStore(directory: base.appending(path: "Away/Backups/Dock", directoryHint: .isDirectory))
    }

    private var originalURL: URL { directory.appending(path: "original.plist") }
    private var historyURL: URL { directory.appending(path: "history.plist") }

    public func loadOriginal() throws -> DockBackup? {
        try load(DockBackup.self, from: originalURL)
    }

    public func saveOriginal(_ backup: DockBackup) throws {
        try save(backup, to: originalURL)
    }

    public func loadHistory() throws -> [DockUndoEntry] {
        try load([DockUndoEntry].self, from: historyURL) ?? []
    }

    public func saveHistory(_ history: [DockUndoEntry]) throws {
        try save(history, to: historyURL)
    }

    private func load<T: Decodable>(_ type: T.Type, from url: URL) throws -> T? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try PropertyListDecoder().decode(type, from: Data(contentsOf: url))
    }

    private func save<T: Encodable>(_ value: T, to url: URL) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        try encoder.encode(value).write(to: url, options: .atomic)
    }
}

/// In-memory store for tests.
public final class InMemoryDockBackupStore: DockBackupStore, @unchecked Sendable {
    private let lock = NSLock()
    private var original: DockBackup?
    private var history: [DockUndoEntry] = []

    public init() {}

    public func loadOriginal() throws -> DockBackup? { lock.withLock { original } }
    public func saveOriginal(_ backup: DockBackup) throws { lock.withLock { original = backup } }
    public func loadHistory() throws -> [DockUndoEntry] { lock.withLock { history } }
    public func saveHistory(_ history: [DockUndoEntry]) throws { lock.withLock { self.history = history } }
}
