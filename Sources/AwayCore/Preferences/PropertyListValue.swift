import CoreFoundation
import Foundation

/// A typed, `Sendable` mirror of a property list value as stored by `cfprefsd`.
public enum PropertyListValue: Equatable, Codable, Sendable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case date(Date)
    case data(Data)
    case array([PropertyListValue])
    case dictionary([String: PropertyListValue])

    /// Converts a value returned by `CFPreferences` or `PropertyListSerialization`.
    public init?(propertyList value: Any) {
        switch value {
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                self = .bool(number.boolValue)
            } else if CFNumberIsFloatType(number) {
                self = .double(number.doubleValue)
            } else {
                self = .int(number.intValue)
            }
        case let string as String:
            self = .string(string)
        case let date as Date:
            self = .date(date)
        case let data as Data:
            self = .data(data)
        case let array as [Any]:
            var values: [PropertyListValue] = []
            for element in array {
                guard let value = PropertyListValue(propertyList: element) else { return nil }
                values.append(value)
            }
            self = .array(values)
        case let dictionary as [String: Any]:
            var values: [String: PropertyListValue] = [:]
            for (key, element) in dictionary {
                guard let value = PropertyListValue(propertyList: element) else { return nil }
                values[key] = value
            }
            self = .dictionary(values)
        default:
            return nil
        }
    }

    /// The Foundation object to hand back to `CFPreferences`.
    public var propertyListObject: Any {
        switch self {
        case let .bool(value): NSNumber(value: value)
        case let .int(value): NSNumber(value: value)
        case let .double(value): NSNumber(value: value)
        case let .string(value): value as NSString
        case let .date(value): value as NSDate
        case let .data(value): value as NSData
        case let .array(values): values.map(\.propertyListObject) as NSArray
        case let .dictionary(values): values.mapValues(\.propertyListObject) as NSDictionary
        }
    }

    public var boolValue: Bool? {
        switch self {
        case let .bool(value): value
        case let .int(value): value != 0
        default: nil
        }
    }

    public var doubleValue: Double? {
        switch self {
        case let .double(value): value
        case let .int(value): Double(value)
        default: nil
        }
    }

    public var stringValue: String? {
        if case let .string(value) = self { return value }
        return nil
    }
}
