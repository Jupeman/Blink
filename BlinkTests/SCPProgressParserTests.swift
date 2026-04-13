import XCTest
@testable import Blink

final class SCPProgressParserTests: XCTestCase {
    func testParseTypicalLine() {
        let line = "movie.mkv                                    42%  1.8GB  98.2MB/s   00:28 ETA"
        let r = SCPProgressParser.parse(line: line)
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.filename, "movie.mkv")
        XCTAssertEqual(r?.percentage, 42)
        XCTAssertEqual(r?.transferred, "1.8GB")
        XCTAssertEqual(r?.speed, "98.2MB/s")
        XCTAssertEqual(r?.eta, "00:28")
    }

    func testParse100Percent() {
        let line = "file.mp4                                    100% 4096MB 112.5MB/s   00:00"
        let r = SCPProgressParser.parse(line: line)
        XCTAssertEqual(r?.percentage, 100)
    }

    func testParseSingleDigitPercent() {
        let line = "large.iso                                      3%  128MB  45.0MB/s   01:45 ETA"
        XCTAssertEqual(SCPProgressParser.parse(line: line)?.percentage, 3)
    }

    func testParseKBSpeed() {
        let line = "small.txt                                     100%   45KB  22.5KB/s   00:00"
        XCTAssertEqual(SCPProgressParser.parse(line: line)?.speed, "22.5KB/s")
    }

    func testReturnsNilForNonProgress() {
        XCTAssertNil(SCPProgressParser.parse(line: ""))
        XCTAssertNil(SCPProgressParser.parse(line: "Connection closed."))
    }

    func testHandlesCarriageReturn() {
        let line = "\rmovie.mkv                                    42%  1.8GB  98.2MB/s   00:28 ETA\r"
        XCTAssertEqual(SCPProgressParser.parse(line: line)?.percentage, 42)
    }

    func testFilenameWithSpaces() {
        let line = "The Martian 4k.mkv                           42%   18GB  98.2MB/s   04:28 ETA"
        let r = SCPProgressParser.parse(line: line)
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.filename, "The Martian 4k.mkv")
        XCTAssertEqual(r?.percentage, 42)
        XCTAssertEqual(r?.speed, "98.2MB/s")
    }

    func testFilenameWithMultipleSpaces() {
        let line = "My Movie File (2024).mkv                     67% 2048MB  55.3MB/s   00:15 ETA"
        let r = SCPProgressParser.parse(line: line)
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.filename, "My Movie File (2024).mkv")
        XCTAssertEqual(r?.percentage, 67)
    }
}
