import Foundation

/// The only place Away writes Dock preferences.
///
/// Every change is reversible: the whole domain is saved once before Away's
/// first write (`original`), and each `apply` records what it replaced so it
/// can be undone without reverting edits the user made in the meantime.
public actor DockPreferencesStore {
    public static let historyLimit = 30

    private let domain: PreferencesDomain
    private let backups: DockBackupStore
    private let restarter: DockRestarting
    private let now: @Sendable () -> Date

    public init(
        domain: PreferencesDomain = SystemPreferencesDomain(domain: DockPreferenceKey.domain),
        backups: DockBackupStore,
        restarter: DockRestarting = CoalescingDockRestarter(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.domain = domain
        self.backups = backups
        self.restarter = restarter
        self.now = now
    }

    public func value(for key: DockPreferenceKey) -> PropertyListValue? {
        domain.value(forKey: key.rawValue)
    }

    public var canUndo: Bool {
        (try? backups.loadHistory().isEmpty == false) ?? false
    }

    public var hasOriginalBackup: Bool {
        (try? backups.loadOriginal() != nil) ?? false
    }

    /// Writes the changes and restarts the Dock once. Changes that would not
    /// alter the current value are skipped; if nothing changes, nothing happens.
    @discardableResult
    public func apply(_ changes: [DockPreferenceChange]) throws -> Bool {
        var previousValues: [String: PropertyListValue] = [:]
        var absentKeys: [String] = []
        var effective: [DockPreferenceChange] = []

        for change in changes {
            let key = change.key.rawValue
            let current = domain.value(forKey: key)
            guard current != change.value else { continue }
            if previousValues[key] == nil, !absentKeys.contains(key) {
                if let current { previousValues[key] = current } else { absentKeys.append(key) }
            }
            effective.append(change)
        }
        guard !effective.isEmpty else { return false }

        try ensureOriginalBackup()
        var history = try backups.loadHistory()
        history.append(DockUndoEntry(date: now(), previousValues: previousValues, absentKeys: absentKeys))
        try backups.saveHistory(Array(history.suffix(Self.historyLimit)))

        for change in effective {
            domain.setValue(change.value, forKey: change.key.rawValue)
        }
        commit()
        return true
    }

    /// Reverts the most recent `apply`.
    @discardableResult
    public func undo() throws -> Bool {
        var history = try backups.loadHistory()
        guard let entry = history.popLast() else { return false }

        for (key, value) in entry.previousValues {
            domain.setValue(value, forKey: key)
        }
        for key in entry.absentKeys {
            domain.setValue(nil, forKey: key)
        }
        try backups.saveHistory(history)
        commit()
        return true
    }

    /// Puts the whole Dock domain back exactly as it was before Away's first change.
    @discardableResult
    public func restoreOriginal() throws -> Bool {
        guard let original = try backups.loadOriginal() else { return false }

        for key in domain.allValues().keys where original.values[key] == nil {
            domain.setValue(nil, forKey: key)
        }
        for (key, value) in original.values {
            domain.setValue(value, forKey: key)
        }
        try backups.saveHistory([])
        commit()
        return true
    }

    /// Removes every behavior key Away manages so macOS falls back to its
    /// defaults, keeping the apps and folders the user pinned to the Dock.
    @discardableResult
    public func resetToSystemDefaults() throws -> Bool {
        let changes = DockPreferenceKey.allCases
            .filter { !$0.isUserContent }
            .map { DockPreferenceChange($0, nil) }
        return try apply(changes)
    }

    private func ensureOriginalBackup() throws {
        guard try backups.loadOriginal() == nil else { return }
        try backups.saveOriginal(DockBackup(date: now(), values: domain.allValues()))
    }

    private func commit() {
        domain.synchronize()
        restarter.requestRestart()
    }
}
