import AwayCore
import XCTest

final class PropertyListValueTests: XCTestCase {
    func testDistinguishesBoolIntAndDouble() {
        XCTAssertEqual(PropertyListValue(propertyList: kCFBooleanTrue as Any), .bool(true))
        XCTAssertEqual(PropertyListValue(propertyList: NSNumber(value: 48)), .int(48))
        XCTAssertEqual(PropertyListValue(propertyList: NSNumber(value: 0.25)), .double(0.25))
    }

    func testRoundTripsNestedValues() throws {
        let value = PropertyListValue.array([
            .dictionary(["tile-type": .string("spacer-tile"), "tile-data": .dictionary([:])]),
            .dictionary(["flag": .bool(false), "size": .int(3), "date": .date(Date(timeIntervalSince1970: 10)), "blob": .data(Data([1, 2]))]),
        ])

        let data = try PropertyListSerialization.data(fromPropertyList: value.propertyListObject, format: .binary, options: 0)
        let decoded = try PropertyListSerialization.propertyList(from: data, format: nil)

        XCTAssertEqual(PropertyListValue(propertyList: decoded), value)
    }

    func testRejectsNonPropertyListValues() {
        XCTAssertNil(PropertyListValue(propertyList: NSObject()))
        XCTAssertNil(PropertyListValue(propertyList: [NSObject()]))
    }

    func testConvenienceAccessors() {
        XCTAssertEqual(PropertyListValue.int(1).boolValue, true)
        XCTAssertEqual(PropertyListValue.int(2).doubleValue, 2)
        XCTAssertNil(PropertyListValue.string("x").doubleValue)
    }
}
