@testable import AwayCore
import XCTest

@MainActor
final class DockHoverMonitorTests: XCTestCase {
    private let item = DockItem(index: 0, kind: .application, title: "Safari", frame: .zero, url: nil, isRunning: true)

    func testEveryObserverReceivesUpdates() {
        let monitor = DockHoverMonitor()
        var first: [DockItem?] = []
        var second: [DockItem?] = []
        let a = monitor.addObserver { first.append($0) }
        let b = monitor.addObserver { second.append($0) }

        monitor.notify(item)
        monitor.notify(nil)

        XCTAssertEqual(first, [item, nil])
        XCTAssertEqual(second, [item, nil])
        withExtendedLifetime((a, b)) {}
    }

    func testCancelledObserverStopsReceivingUpdates() {
        let monitor = DockHoverMonitor()
        var received = 0
        let observation = monitor.addObserver { _ in received += 1 }

        monitor.notify(item)
        observation.cancel()
        monitor.notify(item)

        XCTAssertEqual(received, 1)
    }
}
