import XCTest
@testable import Blink

@MainActor
final class SettingsStoreTests: XCTestCase {
    private var store: SettingsStore!
    private let suiteName = "com.charlie.blink.tests.\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        store = SettingsStore(userDefaults: UserDefaults(suiteName: suiteName)!)
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testDefaultDestinations() {
        XCTAssertEqual(store.destinations.count, 1)
        XCTAssertEqual(store.destinations[0].name, "Gandalf Movies")
        XCTAssertEqual(store.destinations[0].host, "gandalf")
        XCTAssertTrue(store.destinations[0].isDefault)
    }

    func testActiveDestination() {
        XCTAssertEqual(store.activeDestination?.name, "Gandalf Movies")
    }

    func testAddDestination() {
        store.addDestination(Destination(name: "Test", host: "testhost", remotePath: "/tmp/"))
        XCTAssertEqual(store.destinations.count, 2)
    }

    func testRemoveDestination() {
        let dest = Destination(name: "Test", host: "testhost", remotePath: "/tmp/")
        store.addDestination(dest)
        store.removeDestination(dest)
        XCTAssertEqual(store.destinations.count, 1)
    }

    func testSetDefault() {
        let dest = Destination(name: "Test", host: "testhost", remotePath: "/tmp/")
        store.addDestination(dest)
        store.setDefault(dest)
        XCTAssertEqual(store.activeDestination?.name, "Test")
    }

    func testNotificationsEnabledByDefault() {
        XCTAssertTrue(store.notificationsEnabled)
    }
}
