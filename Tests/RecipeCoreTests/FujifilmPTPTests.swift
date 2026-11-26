import XCTest
@testable import RecipeCore

final class FujifilmPTPTests: XCTestCase {
    func testWordsRetainUnknownValuesAndSignedBits() throws {
        let negative = try FujifilmPropertyValue.decode(Data([0xF1, 0xFF]), for: .highlight)
        XCTAssertEqual(negative, .word(0xFFF1))
        XCTAssertEqual(negative.signedWord, -15) // display conversion intentionally deferred
        XCTAssertEqual(try FujifilmPropertyValue.decode(Data([0xEF, 0xBE]), for: .filmSimulation), .word(0xBEEF))
        for bytes: [UInt8] in [[], [0], [0, 0, 0]] {
            XCTAssertThrowsError(try FujifilmPropertyValue.decode(Data(bytes), for: .clarity))
        }
    }

    func testNamesAcceptBothEmptyFormsAndUCS2() throws {
        for bytes: [UInt8] in [[0], [1, 0, 0]] {
            XCTAssertEqual(try FujifilmPropertyValue.decode(Data(bytes), for: .name), .name(""))
        }
        XCTAssertEqual(try FujifilmPropertyValue.decode(Data([3, 65, 0, 0xE9, 0, 0, 0]), for: .name), .name("Aé"))
        XCTAssertNil(FujifilmPropertyValue.name("A").signedWord)
    }

    func testMalformedNamesFailClosed() {
        let bad: [[UInt8]] = [[], [1], [0, 0], [2, 65, 0], [2, 65, 0, 1, 0],
                             [2, 0, 0, 0, 0], [2, 0, 0xD8, 0, 0]]
        for bytes in bad {
            XCTAssertThrowsError(try FujifilmPropertyValue.decode(Data(bytes), for: .name))
        }
        let valid = Data([3, 65, 0, 66, 0, 0, 0])
        for length in 0..<valid.count {
            XCTAssertThrowsError(try FujifilmPropertyValue.decode(Data(valid.prefix(length)), for: .name))
        }
    }
}
