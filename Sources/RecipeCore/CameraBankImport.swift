import Foundation

public enum CameraImportError: LocalizedError {
    case invalid(String)
    case response(UInt16)
    public var errorDescription: String? {
        switch self {
        case .invalid(let text): return text
        case .response(let code): return String(format: "Camera returned PTP 0x%04X", code)
        }
    }
}

/// The only data-out operation is selecting a bank. No recipe-setting writer exists.
public enum BankImportCommand: Equatable {
    case identity
    case read(FujifilmBankProperty)
    case select(UInt16)

    public var operation: UInt16 {
        switch self { case .identity: return 0x1001; case .read: return 0x1015; case .select: return 0x1016 }
    }
    public func encoded(transaction: UInt32) throws -> (command: Data, outData: Data?) {
        var parameters: [UInt8] = []
        var out: Data?
        switch self {
        case .identity: break
        case .read(let property): parameters = Self.u32(UInt32(property.rawValue))
        case .select(let bank):
            guard XM5ProtocolReference.customBanks.contains(bank) else { throw CameraImportError.invalid("Refusing a selector outside C1–C4") }
            parameters = Self.u32(UInt32(FujifilmBankProperty.selector.rawValue))
            out = Data([UInt8(bank), 0])
        }
        let bytes = Self.u32(UInt32(12 + parameters.count)) + [1, 0, UInt8(operation & 255), UInt8(operation >> 8)]
            + Self.u32(transaction) + parameters
        return (Data(bytes), out)
    }
    private static func u32(_ n: UInt32) -> [UInt8] {
        [UInt8(n & 255), UInt8((n >> 8) & 255), UInt8((n >> 16) & 255), UInt8(n >> 24)]
    }
    public func payload(data: Data, response: Data, transaction: UInt32) throws -> Data {
        let r = Array(response)
        func u16(_ b: [UInt8], _ i: Int) -> UInt16 { UInt16(b[i]) | UInt16(b[i+1]) << 8 }
        func u32(_ b: [UInt8], _ i: Int) -> UInt32 { UInt32(u16(b, i)) | UInt32(u16(b, i+2)) << 16 }
        guard r.count >= 12, r.count <= 32, (r.count - 12) % 4 == 0,
              u32(r, 0) == r.count, u16(r, 4) == 3, u32(r, 8) == transaction else {
            throw CameraImportError.invalid("Malformed or mismatched PTP response")
        }
        guard u16(r, 6) == 0x2001 else { throw CameraImportError.response(u16(r, 6)) }
        guard data.count <= 1024 * 1024 else { throw CameraImportError.invalid("Oversized PTP payload") }
        let b = Array(data)
        if b.count >= 12, u16(b, 4) == 2 {
            guard u32(b, 0) == b.count, u16(b, 6) == operation, u32(b, 8) == transaction else {
                throw CameraImportError.invalid("Malformed or mismatched PTP data container")
            }
            return Data(b.dropFirst(12))
        }
        return data
    }
}

public struct CameraBankSnapshot {
    public let bank: UInt16
    public let values: [FujifilmBankProperty: Data]
    public let unsupported: [UInt16]
    public init(bank: UInt16, values: [FujifilmBankProperty: Data], unsupported: [UInt16]) {
        self.bank = bank; self.values = values; self.unsupported = unsupported
    }
}

public enum CameraBankReader {
    /// Requires an open, exclusively owned session. The caller must invalidate its
    /// transport on timeout/disconnect so restoration cannot overlap a pending command.
    public static func read(identity: CameraIdentity,
                            exchange: (BankImportCommand) async throws -> Data) async throws -> [CameraBankSnapshot] {
        guard identity.model == "X-M5" || identity.model == "FUJIFILM X-M5",
              identity.firmware == XM5ProtocolReference.reportedFirmware else {
            throw CameraImportError.invalid("This experimental import is limited to X-M5 firmware 1.30. No selector changed.")
        }
        let original = try word(try await exchange(.read(.selector)), property: .selector)
        guard XM5ProtocolReference.customBanks.contains(original) else {
            throw CameraImportError.invalid("Original selector is outside C1–C4; refusing to change it")
        }
        var snapshots: [CameraBankSnapshot] = []
        var failure: Error?
        do {
            for bank in XM5ProtocolReference.customBanks {
                _ = try await exchange(.select(bank))
                try await Task.sleep(nanoseconds: 100_000_000)
                guard try word(try await exchange(.read(.selector)), property: .selector) == bank else {
                    throw CameraImportError.invalid("Bank selector read-back mismatch")
                }
                var values: [FujifilmBankProperty: Data] = [:]
                var unsupported: [UInt16] = []
                for property in FujifilmBankProperty.allCases where property != .selector {
                    do {
                        let data = try await exchange(.read(property))
                        _ = try FujifilmPropertyValue.decode(data, for: property)
                        values[property] = data
                    } catch CameraImportError.response(0x200A) {
                        if property == .name || property == .filmSimulation { throw CameraImportError.response(0x200A) }
                        unsupported.append(property.rawValue)
                    }
                }
                snapshots.append(CameraBankSnapshot(bank: bank, values: values, unsupported: unsupported))
            }
        } catch { failure = error }
        // Exactly one restoration attempt, including after a failed select. Never
        // retry a timed-out transport; the adapter must reject it without sending.
        do {
            _ = try await exchange(.select(original))
            try await Task.sleep(nanoseconds: 100_000_000)
            guard try word(try await exchange(.read(.selector)), property: .selector) == original else {
                throw CameraImportError.invalid("Original selector did not read back")
            }
        } catch {
            throw CameraImportError.invalid("Import stopped. Original selector restoration is UNCONFIRMED: \(error.localizedDescription). No recipe-setting writes were sent. Earlier error: \(failure?.localizedDescription ?? "none")")
        }
        if let failure { throw CameraImportError.invalid("Import stopped; original selector restored. \(failure.localizedDescription)") }
        return snapshots
    }
    private static func word(_ data: Data, property: FujifilmBankProperty) throws -> UInt16 {
        guard case .word(let value) = try FujifilmPropertyValue.decode(data, for: property) else {
            throw CameraImportError.invalid("Expected a numeric property")
        }
        return value
    }
}

/// ImageCaptureCore can renumber wire transactions. Use this only inside a
/// request-specific callback guarded by session identity, timeout and generation.
/// A direct USB transport must instead compare with its submitted transaction ID.
public enum PTPCallbackResponse {
    public static func wireTransaction(in response: Data) throws -> UInt32 {
        let b = Array(response)
        guard b.count >= 12, b.count <= 32, (b.count - 12) % 4 == 0,
              b[4] == 3, b[5] == 0 else { throw CameraImportError.invalid("Invalid callback response header") }
        func u32(_ i: Int) -> UInt32 {
            UInt32(b[i]) | UInt32(b[i+1]) << 8 | UInt32(b[i+2]) << 16 | UInt32(b[i+3]) << 24
        }
        guard u32(0) == b.count else { throw CameraImportError.invalid("Invalid callback response length") }
        return u32(8)
    }
}
