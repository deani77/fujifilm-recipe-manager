import XCTest
@testable import RecipeCore

final class CameraBankImportTests: XCTestCase {
    private var identity: CameraIdentity {
        CameraIdentity(manufacturer: "FUJIFILM", model: "X-M5", firmware: "1.30", advertisedPropertyCount: 61)
    }
    private func data(_ value: UInt16) -> Data { Data([UInt8(value & 255), UInt8(value >> 8)]) }

    func testCommandsOnlyWriteSelectorAndRejectOtherBanks() throws {
        let select = try BankImportCommand.select(4).encoded(transaction: 7)
        XCTAssertEqual(select.command, Data([16,0,0,0,1,0,0x16,0x10,7,0,0,0,0x8C,0xD1,0,0]))
        XCTAssertEqual(select.outData, Data([4,0]))
        for n: UInt16 in [0,5,7,65535] { XCTAssertThrowsError(try BankImportCommand.select(n).encoded(transaction: 1)) }
        for property in FujifilmBankProperty.allCases {
            XCTAssertNil(try BankImportCommand.read(property).encoded(transaction: 2).outData)
        }
    }
    func testReplyValidationAndUnsupportedStatus() throws {
        let response = Data([12,0,0,0,3,0,1,0x20,2,0,0,0])
        XCTAssertEqual(try BankImportCommand.read(.selector).payload(data: data(3), response: response, transaction: 2), data(3))
        XCTAssertThrowsError(try BankImportCommand.read(.selector).payload(data: data(3), response: response, transaction: 3))
        for length in 0..<response.count {
            XCTAssertThrowsError(try BankImportCommand.read(.selector).payload(data: data(3), response: Data(response.prefix(length)), transaction: 2))
        }
        let container = Data([14,0,0,0,2,0,0x15,0x10,2,0,0,0,3,0])
        XCTAssertEqual(try BankImportCommand.read(.selector).payload(data: container, response: response, transaction: 2), data(3))
        var bad = container; bad[8] = 9
        XCTAssertThrowsError(try BankImportCommand.read(.selector).payload(data: bad, response: response, transaction: 2))
        var unsupported = response; unsupported[6] = 0x0A
        XCTAssertThrowsError(try BankImportCommand.read(.clarity).payload(data: Data(), response: unsupported, transaction: 2)) { error in
            guard case CameraImportError.response(0x200A) = error else { return XCTFail("Wrong error") }
        }
    }
    func testFourBanksReadAndOriginalSelectorRestored() async throws {
        var selector: UInt16 = 3
        var selected: [UInt16] = []
        let banks = try await CameraBankReader.read(identity: identity) { command in
            switch command {
            case .identity: XCTFail("Reader must use previously validated identity"); return Data()
            case .select(let n): selected.append(n); selector = n; return Data()
            case .read(.selector): return self.data(selector)
            case .read(.name): return Data([3,67,0,UInt8(48 + selector),0,0,0])
            case .read(.smoothSkin): throw CameraImportError.response(0x200A)
            case .read: return self.data(1)
            }
        }
        XCTAssertEqual(banks.map(\.bank), [1,2,3,4])
        XCTAssertEqual(selected, [1,2,3,4,3]); XCTAssertEqual(selector, 3)
        XCTAssertEqual(banks[0].unsupported, [0xD198])
    }
    func testFailureStopsFurtherBankReadsAndRestoresOnce() async {
        var selector: UInt16 = 4
        var selected: [UInt16] = []
        do {
            _ = try await CameraBankReader.read(identity: identity) { command in
                switch command {
                case .select(let n): selected.append(n); selector = n; return Data()
                case .read(.selector): return self.data(selector)
                default: throw CameraImportError.response(0x2002)
                }
            }
            XCTFail("Expected read failure")
        } catch { XCTAssertTrue(error.localizedDescription.contains("original selector restored")) }
        XCTAssertEqual(selected, [1,4]); XCTAssertEqual(selector, 4)
    }
    func testRestorationMismatchIsNotRetriedOrReportedAsSuccess() async {
        var selector: UInt16 = 2
        var selected: [UInt16] = []
        do {
            _ = try await CameraBankReader.read(identity: identity) { command in
                switch command {
                case .select(let n): selected.append(n); if n != 2 { selector = n }; return Data()
                case .read(.selector): return self.data(selector)
                default: throw CameraImportError.response(0x2002)
                }
            }
            XCTFail("Expected restore failure")
        } catch { XCTAssertTrue(error.localizedDescription.contains("UNCONFIRMED")) }
        XCTAssertEqual(selected, [1,2])
    }
    func testUnknownFirmwareAndInvalidOriginalSelectorNeverWrite() async {
        var calls: [BankImportCommand] = []
        let other = CameraIdentity(manufacturer: "FUJIFILM", model: "X-M5", firmware: "9.99", advertisedPropertyCount: 61)
        do {
            _ = try await CameraBankReader.read(identity: other) { command in calls.append(command); return Data() }
            XCTFail("Expected profile refusal")
        } catch {}
        XCTAssertTrue(calls.isEmpty)
        do {
            _ = try await CameraBankReader.read(identity: identity) { command in calls.append(command); return self.data(0) }
            XCTFail("Expected invalid-selector refusal")
        } catch {}
        XCTAssertEqual(calls, [.read(.selector)])
    }
    func testRecipeConversionKeepsRawUnknownsHalfStepsAndNREncoding() throws {
        let snapshot = CameraBankSnapshot(bank: 1, values: [.name:Data([0]), .filmSimulation:data(11),
            .highlight:data(UInt16(bitPattern: -15)), .highISONoiseReduction:data(0x8000),
            .grain:data(7), .whiteBalance:data(0x8007), .kelvin:data(5300), .color:data(0x8000)], unsupported: [])
        let doc = try CameraRecipeDocument.make(identity: identity, banks: [snapshot])
        let restored = try RecipeDocument(data: doc.encoded())
        let recipe = restored.recipes[0]
        XCTAssertEqual(recipe.name, "X-M5 C1")
        XCTAssertEqual(recipe.parameters["filmSimulation"], .string("Classic Chrome"))
        XCTAssertEqual(recipe.parameters["highlight"], .number(Decimal(string: "-1.5")!))
        XCTAssertEqual(recipe.parameters["highISONoiseReduction"], .number(-4))
        XCTAssertEqual(recipe.parameters["grainStrength"], .string("Off"))
        XCTAssertEqual(recipe.parameters["grainSize"], .string("Large"))
        XCTAssertEqual(recipe.parameters["colorTemperature"], .number(5300))
        XCTAssertNil(recipe.parameters["color"])
        XCTAssertEqual(recipe.fields["cameraImport"]?.object?["rawPropertiesLEHex"]?.object?["0xD19F"], .string("0080"))
    }
}
