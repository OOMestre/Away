import Foundation

public enum DockSpacerSide: String, CaseIterable, Sendable {
    case apps
    case others

    public var preferenceKey: DockPreferenceKey {
        self == .apps ? .persistentApps : .persistentOthers
    }
}

public enum DockSpacerSize: String, Sendable {
    case large = "spacer-tile"
    case small = "small-spacer-tile"
}

public enum DockSpacerEdit: Sendable {
    case add(DockSpacerSize)
    case move(Int, Int)
    case remove(Int)
}

public enum DockSpacerError: LocalizedError {
    case missingDockItems
    case invalidDockItems
    case invalidPosition
    case itemIsNotSpacer
    case dockChanged

    public var errorDescription: String? {
        switch self {
        case .missingDockItems: "This side of the Dock has no saved item list yet. No changes were made."
        case .invalidDockItems: "The Dock items could not be read safely. No changes were made."
        case .invalidPosition: "That Dock position is no longer available."
        case .itemIsNotSpacer: "Only spacers can be moved or removed here."
        case .dockChanged: "The Dock changed since this list was loaded. Refresh and try again."
        }
    }
}

/// Keeps each existing tile untouched while editing only spacer positions.
public struct DockSpacerLayout: Sendable {
    public let original: PropertyListValue?
    public private(set) var items: [PropertyListValue]

    public init(_ value: PropertyListValue?) throws {
        original = value
        guard let value else { throw DockSpacerError.missingDockItems }
        guard case let .array(items) = value,
              items.allSatisfy({ if case .dictionary = $0 { return true }; return false }) else {
            throw DockSpacerError.invalidDockItems
        }
        self.items = items
    }

    public func spacerSize(at index: Int) -> DockSpacerSize? {
        guard items.indices.contains(index), case let .dictionary(tile) = items[index],
              case let .string(type)? = tile["tile-type"] else { return nil }
        return DockSpacerSize(rawValue: type)
    }

    public func label(at index: Int) -> String {
        guard items.indices.contains(index), case let .dictionary(tile) = items[index] else {
            return "Dock item"
        }
        if let size = spacerSize(at: index) {
            return size == .large ? "Large spacer" : "Small spacer"
        }
        if case let .dictionary(data)? = tile["tile-data"],
           case let .string(name)? = data["file-label"], !name.isEmpty {
            return name
        }
        return "Dock item \(index + 1)"
    }

    public mutating func edit(_ change: DockSpacerEdit) throws {
        switch change {
        case let .add(size):
            items.append(.dictionary([
                "tile-type": .string(size.rawValue),
                "tile-data": .dictionary([:]),
            ]))
        case let .move(from, to):
            guard items.indices.contains(from), items.indices.contains(to) else {
                throw DockSpacerError.invalidPosition
            }
            guard spacerSize(at: from) != nil else { throw DockSpacerError.itemIsNotSpacer }
            let item = items.remove(at: from)
            items.insert(item, at: to)
        case let .remove(index):
            guard items.indices.contains(index) else { throw DockSpacerError.invalidPosition }
            guard spacerSize(at: index) != nil else { throw DockSpacerError.itemIsNotSpacer }
            items.remove(at: index)
        }
    }

    public var propertyListValue: PropertyListValue { .array(items) }
}
