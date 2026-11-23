import Foundation

/// JSON values are retained even when a newer producer adds fields this app cannot edit.
public enum JSONValue: Codable, Equatable {
    case string(String), number(Decimal), bool(Bool), object([String: JSONValue]), array([JSONValue]), null

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode(Decimal.self) { self = .number(v) }
        else if let v = try? c.decode([String: JSONValue].self) { self = .object(v) }
        else { self = .array(try c.decode([JSONValue].self)) }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        }
    }
    public var string: String? { if case .string(let v) = self { return v }; return nil }
    public var object: [String: JSONValue]? { if case .object(let v) = self { return v }; return nil }
    public var array: [JSONValue]? { if case .array(let v) = self { return v }; return nil }
}

public enum LibraryError: LocalizedError {
    case invalid(String), newerVersion, conflict, tooLarge, metadataConflict(String)
    public var errorDescription: String? {
        switch self {
        case .invalid(let reason): return "Invalid recipe document: \(reason)"
        case .newerVersion: return "This document uses a newer schema. It has not been changed."
        case .conflict: return "The library changed on disk. Reload it before saving; your draft has not been saved."
        case .tooLarge: return "Recipe documents must be 5 MB or smaller."
        case .metadataConflict(let key): return "Import contains conflicting library metadata (\(key)). Nothing was imported."
        }
    }
}

public struct Recipe: Identifiable, Equatable {
    public private(set) var fields: [String: JSONValue]
    public var id: UUID { UUID(uuidString: fields["id"]!.string!)! }
    public var name: String {
        get { fields["name"]?.string ?? "" }
        set { fields["name"] = .string(newValue) }
    }
    public var parameters: [String: JSONValue] {
        get { fields["parameters"]?.object ?? [:] }
        set { fields["parameters"] = .object(newValue) }
    }
    public init(name: String = "Untitled recipe") {
        fields = ["id": .string(UUID().uuidString), "name": .string(name), "parameters": .object([:])]
    }
    public init(fields: [String: JSONValue]) throws {
        guard let id = fields["id"]?.string, UUID(uuidString: id) != nil,
              let name = fields["name"]?.string, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              fields["parameters"]?.object != nil else {
            throw LibraryError.invalid("each recipe needs a UUID, a name, and a parameters object")
        }
        self.fields = fields
    }
    public func duplicated() -> Recipe {
        var copy = self
        copy.fields["id"] = .string(UUID().uuidString)
        copy.name += " copy"
        return copy
    }
    public subscript(text key: String) -> String {
        get { fields[key]?.string ?? "" }
        set { fields[key] = .string(newValue) }
    }
}

public struct RecipeDocument: Equatable {
    public static let maximumBytes = 5 * 1024 * 1024
    public var metadata: [String: JSONValue]
    public var recipes: [Recipe]
    public init() { metadata = [:]; recipes = [] }

    public init(data: Data) throws {
        guard data.count <= Self.maximumBytes else { throw LibraryError.tooLarge }
        guard var root = try JSONDecoder().decode(JSONValue.self, from: data).object,
              case .number(let version) = root["schemaVersion"] else {
            throw LibraryError.invalid("missing schemaVersion")
        }
        guard version == 0 || version == 1 else {
            if version > 1 { throw LibraryError.newerVersion }
            throw LibraryError.invalid("unsupported schemaVersion")
        }
        guard let records = root.removeValue(forKey: "recipes")?.array else {
            throw LibraryError.invalid("missing recipes array")
        }
        root.removeValue(forKey: "schemaVersion")
        metadata = root
        recipes = try records.map { value in
            guard var fields = value.object else { throw LibraryError.invalid("recipe must be an object") }
            // Explicit v0 migration: parameter values used to be named settings.
            if version == 0 {
                guard fields["parameters"] == nil, let settings = fields.removeValue(forKey: "settings")?.object else {
                    throw LibraryError.invalid("v0 needs settings and cannot also contain parameters")
                }
                fields["parameters"] = .object(settings)
            }
            return try Recipe(fields: fields)
        }
        try validate()
    }

    public func validate() throws {
        guard metadata["recipes"] == nil, metadata["schemaVersion"] == nil else {
            throw LibraryError.invalid("reserved metadata key")
        }
        var ids = Set<UUID>()
        for record in recipes {
            let validated = try Recipe(fields: record.fields)
            guard ids.insert(validated.id).inserted else { throw LibraryError.invalid("duplicate recipe UUID") }
        }
    }

    public func encoded() throws -> Data {
        try validate()
        var root = metadata
        root["schemaVersion"] = .number(1)
        root["recipes"] = .array(recipes.map { .object($0.fields) })
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(JSONValue.object(root))
        guard data.count <= Self.maximumBytes else { throw LibraryError.tooLarge }
        return data
    }

    /// An import is all-or-nothing. Never silently overwrite an existing UUID or unknown metadata.
    public func merging(_ incoming: RecipeDocument) throws -> RecipeDocument {
        var result = self
        for (key, value) in incoming.metadata {
            if let old = result.metadata[key], old != value { throw LibraryError.metadataConflict(key) }
            result.metadata[key] = value
        }
        result.recipes += incoming.recipes
        try result.validate()
        return result
    }
}
