import XCTest
@testable import RecipeCore

final class LibraryTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        try Data(contentsOf: Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")!)
    }
    private func temporaryURL() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir.appendingPathComponent("library.json")
    }
    func testEditingPreservesUnknownFieldsAndDecimalValues() throws {
        var doc = try RecipeDocument(data: fixture("future-fields-v1"))
        let original = doc
        doc.recipes[0].name = "Edited locally"
        let restored = try RecipeDocument(data: doc.encoded())
        XCTAssertEqual(restored.metadata, original.metadata)
        XCTAssertEqual(restored.recipes[0].parameters, original.recipes[0].parameters)
        XCTAssertEqual(restored.recipes[0].fields["futureMetadata"], original.recipes[0].fields["futureMetadata"])
        XCTAssertEqual(restored.recipes[0].parameters["highlight"], .number(Decimal(string: "-1.5")!))
        XCTAssertNil(restored.recipes[0].parameters["sharpness"])
        XCTAssertEqual(restored.recipes[0].parameters["color"], .number(0))
    }
    func testVersionZeroMigrationPreservesUnknowns() throws {
        let doc = try RecipeDocument(data: fixture("legacy-v0"))
        let root = try JSONDecoder().decode(JSONValue.self, from: doc.encoded()).object!
        XCTAssertEqual(root["schemaVersion"], .number(1))
        XCTAssertEqual(doc.metadata["futureRoot"], .string("retain me"))
        XCTAssertEqual(doc.recipes[0].parameters["highlight"], .number(Decimal(string: "0.5")!))
        XCTAssertEqual(doc.recipes[0].parameters["unknown"], .string("retained"))
        XCTAssertNil(doc.recipes[0].fields["settings"])
    }
    func testRejectsDuplicateIDsAndNewerSchema() throws {
        let doc = try RecipeDocument(data: fixture("future-fields-v1"))
        XCTAssertThrowsError(try doc.merging(doc))
        let newer = Data(String(data: try fixture("future-fields-v1"), encoding: .utf8)!.replacingOccurrences(of: "\"schemaVersion\": 1", with: "\"schemaVersion\": 2").utf8)
        XCTAssertThrowsError(try RecipeDocument(data: newer))
        XCTAssertThrowsError(try RecipeDocument(data: Data("{}".utf8)))
    }
    func testImportDoesNotDiscardConflictingRootMetadata() throws {
        var first = RecipeDocument(); first.metadata["extension"] = .string("a")
        var second = RecipeDocument(); second.metadata["extension"] = .string("b")
        XCTAssertThrowsError(try first.merging(second))
        second.metadata["extension"] = .string("a")
        second.recipes = [Recipe(name: "Added")]
        XCTAssertEqual(try first.merging(second).recipes.count, 1)
    }
    func testPersistencePreviousCopyAndConcurrentWriterProtection() throws {
        let url = try temporaryURL()
        let first = LibraryRepository(url: url)
        var doc = try first.load()
        doc.recipes.append(Recipe(name: "One"))
        try first.save(doc)
        let old = try Data(contentsOf: url)
        let second = LibraryRepository(url: url)
        _ = try second.load()
        doc.recipes[0].name = "Two"
        try first.save(doc)
        XCTAssertEqual(try Data(contentsOf: url.appendingPathExtension("previous")), old)
        XCTAssertThrowsError(try second.save(RecipeDocument()))
        XCTAssertEqual(try RecipeDocument(data: Data(contentsOf: url)).recipes[0].name, "Two")
    }
    func testCorruptOrNewerLibraryIsNeverOverwritten() throws {
        for bytes in [Data("not json".utf8), Data("{\"schemaVersion\":99,\"recipes\":[]}".utf8)] {
            let url = try temporaryURL()
            try bytes.write(to: url)
            let repo = LibraryRepository(url: url)
            XCTAssertThrowsError(try repo.load())
            XCTAssertThrowsError(try repo.save(RecipeDocument()))
            XCTAssertEqual(try Data(contentsOf: url), bytes)
        }
    }
    func testExternalCorruptionAfterLoadIsNotOverwritten() throws {
        let url = try temporaryURL()
        let repo = LibraryRepository(url: url); _ = try repo.load()
        let bytes = Data("corrupt external edit".utf8); try bytes.write(to: url)
        XCTAssertThrowsError(try repo.save(RecipeDocument()))
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }
    func testDocumentSizeLimitAndInvalidName() throws {
        XCTAssertThrowsError(try RecipeDocument(data: Data(repeating: 32, count: RecipeDocument.maximumBytes + 1)))
        var doc = RecipeDocument(); doc.recipes = [Recipe(name: " ")]
        XCTAssertThrowsError(try doc.encoded())
    }
    func testNumericInputRequiresWholeValidValueAndKeepsHalfSteps() throws {
        let highlight = RecipeParameter.all.first { $0.id == "highlight" }!
        XCTAssertEqual(try highlight.parse("-1.5"), .number(Decimal(string: "-1.5")!))
        XCTAssertNil(try highlight.parse(""))
        for invalid in ["1abc", "1,5", "1.25", "5", "NaN", "1e2"] { XCTAssertThrowsError(try highlight.parse(invalid)) }
        let red = RecipeParameter.all.first { $0.id == "wbShiftRed" }!
        XCTAssertThrowsError(try red.parse("0.5"))
    }
}
