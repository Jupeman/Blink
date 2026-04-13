import XCTest
@testable import Blink

final class SSHConfigParserTests: XCTestCase {
    func testParseSingleHost() {
        let config = """
        Host myserver
            HostName 192.168.1.100
            User admin
            Port 2222
        """
        let hosts = SSHConfigParser.parse(content: config)
        XCTAssertEqual(hosts.count, 1)
        XCTAssertEqual(hosts[0].alias, "myserver")
        XCTAssertEqual(hosts[0].hostName, "192.168.1.100")
        XCTAssertEqual(hosts[0].user, "admin")
        XCTAssertEqual(hosts[0].port, 2222)
    }

    func testParseMultipleHosts() {
        let config = """
        Host alpha
            HostName alpha.example.com
            User alice

        Host beta
            HostName beta.example.com
            User bob
            Port 2200
        """
        let hosts = SSHConfigParser.parse(content: config)
        XCTAssertEqual(hosts.count, 2)
        XCTAssertEqual(hosts[0].alias, "alpha")
        XCTAssertEqual(hosts[1].alias, "beta")
        XCTAssertEqual(hosts[1].port, 2200)
    }

    func testIgnoresWildcardHost() {
        let config = """
        Host *
            ServerAliveInterval 60

        Host gandalf
            HostName 10.0.0.50
            User charlie
        """
        let hosts = SSHConfigParser.parse(content: config)
        XCTAssertEqual(hosts.count, 1)
        XCTAssertEqual(hosts[0].alias, "gandalf")
    }

    func testHostWithMinimalConfig() {
        let config = """
        Host simple
            HostName 10.0.0.1
        """
        let hosts = SSHConfigParser.parse(content: config)
        XCTAssertEqual(hosts.count, 1)
        XCTAssertNil(hosts[0].user)
        XCTAssertNil(hosts[0].port)
    }

    func testEmptyConfigReturnsEmpty() {
        XCTAssertTrue(SSHConfigParser.parse(content: "").isEmpty)
    }

    func testDisplayNameWithUser() {
        let host = SSHHost(alias: "test", hostName: "example.com", user: "admin", port: nil)
        XCTAssertEqual(host.displayName, "admin@example.com")
    }

    func testDisplayNameFallsBackToAlias() {
        let host = SSHHost(alias: "myhost", hostName: nil, user: nil, port: nil)
        XCTAssertEqual(host.displayName, "myhost")
    }

    func testCaseInsensitiveKeys() {
        let config = """
        Host myserver
            hostname 10.0.0.1
            user admin
        """
        let hosts = SSHConfigParser.parse(content: config)
        XCTAssertEqual(hosts[0].hostName, "10.0.0.1")
        XCTAssertEqual(hosts[0].user, "admin")
    }

    func testIgnoresComments() {
        let config = """
        # Comment
        Host myserver
            # Another
            HostName 10.0.0.1
            User admin
        """
        let hosts = SSHConfigParser.parse(content: config)
        XCTAssertEqual(hosts.count, 1)
        XCTAssertEqual(hosts[0].user, "admin")
    }
}
