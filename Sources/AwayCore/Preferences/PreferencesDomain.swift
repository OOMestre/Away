import CoreFoundation
import Foundation

/// Read/write access to one preferences domain of the current user.
///
/// Abstracted so tests never touch the real `com.apple.dock` domain.
public protocol PreferencesDomain: AnyObject, Sendable {
    func value(forKey key: String) -> PropertyListValue?
    func setValue(_ value: PropertyListValue?, forKey key: String)
    func allValues() -> [String: PropertyListValue]
    func synchronize()
}

/// `CFPreferences`-backed domain, equivalent to the `defaults` command.
public final class SystemPreferencesDomain: PreferencesDomain, @unchecked Sendable {
    private let domain: CFString

    public init(domain: String) {
        self.domain = domain as CFString
    }

    public func value(forKey key: String) -> PropertyListValue? {
        CFPreferencesCopyAppValue(key as CFString, domain).flatMap { PropertyListValue(propertyList: $0) }
    }

    public func setValue(_ value: PropertyListValue?, forKey key: String) {
        CFPreferencesSetAppValue(key as CFString, value?.propertyListObject as CFPropertyList?, domain)
    }

    public func allValues() -> [String: PropertyListValue] {
        let keys = CFPreferencesCopyKeyList(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String] ?? []
        var values: [String: PropertyListValue] = [:]
        for key in keys {
            values[key] = value(forKey: key)
        }
        return values
    }

    public func synchronize() {
        CFPreferencesAppSynchronize(domain)
    }
}

/// In-memory domain for tests and previews.
public final class InMemoryPreferencesDomain: PreferencesDomain, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: PropertyListValue]
    public private(set) var synchronizeCount = 0

    public init(_ values: [String: PropertyListValue] = [:]) {
        storage = values
    }

    public func value(forKey key: String) -> PropertyListValue? {
        lock.withLock { storage[key] }
    }

    public func setValue(_ value: PropertyListValue?, forKey key: String) {
        lock.withLock { storage[key] = value }
    }

    public func allValues() -> [String: PropertyListValue] {
        lock.withLock { storage }
    }

    public func synchronize() {
        lock.withLock { synchronizeCount += 1 }
    }
}
