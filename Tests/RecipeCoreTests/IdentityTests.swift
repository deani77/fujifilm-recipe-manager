import XCTest
@testable import RecipeCore

final class IdentityTests: XCTestCase {
    private func u16(_ n: UInt16) -> [UInt8] { [UInt8(n & 255), UInt8(n >> 8)] }
    private func u32(_ n: UInt32) -> [UInt8] { u16(UInt16(n & 65535)) + u16(UInt16(n >> 16)) }
    private func string(_ text: String) -> [UInt8] { [UInt8(text.utf16.count + 1)] + text.utf16.flatMap(u16) + [0, 0] }
    private var response: Data { Data([12,0,0,0,3,0,1,32,1,0,0,0]) }
    private var dataset: Data {
        Data(u16(100) + u32(14) + u16(100) + string("Synthetic vendor") + u16(0)
             + Array(repeating: UInt8(0), count: 20)
             + string("FUJIFILM") + string("X-M5") + string("TEST-FW") + string("DO-NOT-RETAIN-SERIAL"))
    }
    func testIdentityDatasetAndContainerDoNotRetainSerial() throws {
        let identity = try IdentityRequest.decode(data: dataset, response: response)
        XCTAssertEqual(identity.model, "X-M5"); XCTAssertEqual(identity.firmware, "TEST-FW")
        XCTAssertFalse(String(describing: identity).contains("DO-NOT-RETAIN"))
        let container = Data(u32(UInt32(dataset.count + 12)) + u16(2) + u16(0x1001) + u32(1)) + dataset
        XCTAssertEqual(try IdentityRequest.decode(data: container, response: response), identity)
    }
    func testFrameworkCallbackCanUseRenumberedWireTransaction() throws {
        var wireResponse = response; wireResponse[8] = 0x79; wireResponse[9] = 0x0D
        let wireID = try PTPCallbackResponse.wireTransaction(in: wireResponse)
        XCTAssertEqual(wireID, 3449)
        XCTAssertThrowsError(try IdentityRequest.decode(data: dataset, response: wireResponse))
        XCTAssertEqual(try IdentityRequest.decode(data: dataset, response: wireResponse, expectedTransaction: wireID).model, "X-M5")
        let wrapped = Data(u32(UInt32(dataset.count + 12)) + u16(2) + u16(0x1001) + u32(wireID)) + dataset
        XCTAssertEqual(try IdentityRequest.decode(data: wrapped, response: wireResponse, expectedTransaction: wireID).model, "X-M5")
        let wrong = Data(u32(UInt32(dataset.count + 12)) + u16(2) + u16(0x1001) + u32(1)) + dataset
        XCTAssertThrowsError(try IdentityRequest.decode(data: wrong, response: wireResponse, expectedTransaction: wireID))
        for length in 0..<response.count {
            XCTAssertThrowsError(try PTPCallbackResponse.wireTransaction(in: Data(response.prefix(length))))
        }
    }
    func testTruncationResponseMismatchAndBadLengthsFailClosed() throws {
        for length in 0..<dataset.count {
            XCTAssertThrowsError(try IdentityRequest.decode(data: Data(dataset.prefix(length)), response: response))
        }
        var oddResponse = response + Data([0])
        oddResponse[0] = 13
        XCTAssertThrowsError(try IdentityRequest.decode(data: dataset, response: oddResponse))
        XCTAssertThrowsError(try IdentityRequest.decode(data: Data(repeating: 0, count: 1024 * 1024 + 1), response: response))
        var wrongID = response; wrongID[8] = 2
        XCTAssertThrowsError(try IdentityRequest.decode(data: dataset, response: wrongID))
        var errorResponse = response; errorResponse[6] = 2
        XCTAssertThrowsError(try IdentityRequest.decode(data: dataset, response: errorResponse))
        var badArray = dataset
        let arrayOffset = 8 + string("Synthetic vendor").count + 2
        badArray.replaceSubrange(arrayOffset..<(arrayOffset + 4), with: [255,255,255,255])
        XCTAssertThrowsError(try IdentityRequest.decode(data: badArray, response: response))
        let badContainer = Data(u32(12) + u16(2) + u16(0x1001) + u32(1)) + dataset
        XCTAssertThrowsError(try IdentityRequest.decode(data: badContainer, response: response))
    }
}
