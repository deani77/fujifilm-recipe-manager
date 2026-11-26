import Foundation

public struct CameraIdentity: Equatable {
    public let manufacturer: String
    public let model: String
    public let firmware: String
    public let advertisedPropertyCount: Int
}

/// Only GetDeviceInfo is available. No arbitrary opcode, property, selector or data-out API.
public enum IdentityRequest {
    public static let transaction: UInt32 = 1
    public static var command: Data {
        Data([12, 0, 0, 0, 1, 0, 1, 16, 1, 0, 0, 0])
    }
    public static func decode(data: Data, response: Data) throws -> CameraIdentity {
        guard data.count <= 1024 * 1024, response.count >= 12, response.count <= 32, (response.count - 12) % 4 == 0 else {
            throw LibraryError.invalid("invalid PTP response size")
        }
        var r = Cursor(response)
        let length = try r.u32()
        guard length == response.count, try r.u16() == 3, try r.u16() == 0x2001, try r.u32() == transaction else {
            throw LibraryError.invalid("PTP response failed or transaction did not match")
        }
        var payload = data
        // ImageCaptureCore versions may return a data container or the unwrapped dataset.
        // A container-shaped result must validate fully; never silently fall back after a bad header.
        let header = Array(data.prefix(12))
        if header.count == 12, header[4] == 2, header[5] == 0 {
            var container = Cursor(data)
            guard try container.u32() == data.count, try container.u16() == 2,
                  try container.u16() == 0x1001, try container.u32() == transaction else {
                throw LibraryError.invalid("invalid PTP data container")
            }
            payload = Data(data.dropFirst(12))
        }
        var p = Cursor(payload)
        _ = try p.u16() // standard version
        _ = try p.u32() // vendor extension ID
        _ = try p.u16() // vendor extension version
        _ = try p.string()
        _ = try p.u16() // functional mode
        _ = try p.array16() // operations
        _ = try p.array16() // events
        let properties = try p.array16()
        _ = try p.array16() // capture formats
        _ = try p.array16() // image formats
        let manufacturer = try p.string()
        let model = try p.string()
        let firmware = try p.string()
        _ = try p.string() // consume, but deliberately discard serial number
        guard p.isAtEnd, !model.isEmpty else { throw LibraryError.invalid("invalid device identity dataset") }
        return CameraIdentity(manufacturer: manufacturer, model: model, firmware: firmware, advertisedPropertyCount: properties)
    }
}

private struct Cursor {
    let bytes: [UInt8]
    var offset = 0
    init(_ data: Data) { bytes = Array(data) }
    var isAtEnd: Bool { offset == bytes.count }
    mutating func u16() throws -> UInt16 {
        guard offset + 2 <= bytes.count else { throw LibraryError.invalid("truncated PTP dataset") }
        defer { offset += 2 }
        return UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
    }
    mutating func u32() throws -> UInt32 {
        let low = UInt32(try u16()); let high = UInt32(try u16())
        return low | high << 16
    }
    mutating func array16() throws -> Int {
        let count = Int(try u32())
        guard count <= 4096, count <= (bytes.count - offset) / 2 else {
            throw LibraryError.invalid("invalid PTP array length")
        }
        offset += count * 2
        return count
    }
    mutating func string() throws -> String {
        guard offset < bytes.count else { throw LibraryError.invalid("missing PTP string") }
        let count = Int(bytes[offset]); offset += 1
        if count == 0 { return "" }
        guard count * 2 <= bytes.count - offset else { throw LibraryError.invalid("truncated PTP string") }
        let data = Data(bytes[offset..<(offset + (count - 1) * 2)])
        offset += count * 2
        guard bytes[offset - 2] == 0, bytes[offset - 1] == 0,
              let result = String(data: data, encoding: .utf16LittleEndian) else {
            throw LibraryError.invalid("invalid PTP UTF-16 string")
        }
        return result
    }
}
