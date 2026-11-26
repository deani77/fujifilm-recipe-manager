import Foundation

/// Offline protocol vocabulary only: no session, command builder, or data-out API.
/// Mapping provenance and limitations: docs/USB_PROTOCOL.md.
public enum FujifilmBankProperty: UInt16, CaseIterable {
    case selector = 0xD18C, name = 0xD18D
    case imageSize = 0xD18E, imageQuality = 0xD18F
    case dynamicRange = 0xD190, dynamicRangePriority = 0xD191
    case filmSimulation = 0xD192, monochromeWarmCool = 0xD193, monochromeMagentaGreen = 0xD194
    case grain = 0xD195, colorChrome = 0xD196, colorChromeBlue = 0xD197, smoothSkin = 0xD198
    case whiteBalance = 0xD199, wbShiftRed = 0xD19A, wbShiftBlue = 0xD19B, kelvin = 0xD19C
    case highlight = 0xD19D, shadow = 0xD19E, color = 0xD19F, sharpness = 0xD1A0
    case highISONoiseReduction = 0xD1A1, clarity = 0xD1A2
    case lensModulationOptimizer = 0xD1A3, colorSpace = 0xD1A4
}

/// Reported profile, not a declaration that a connected camera has been validated.
public enum XM5ProtocolReference {
    public static let usbVendorID: UInt16 = 0x04CB
    public static let observedUSBProductID: UInt16 = 0x030C
    public static let reportedFirmware = "1.30"
    public static let customBanks: ClosedRange<UInt16> = 1...4
    public static let locallyValidatedRecipeAccess = false
}

/// Decodes an already-unwrapped property payload. Transport must validate the PTP
/// container, response status and transaction separately before passing bytes here.
/// Retains raw bits instead of guessing undocumented enums or display units.
public enum FujifilmPropertyValue: Equatable {
    case word(UInt16)
    case name(String)

    public static func decode(_ payload: Data, for property: FujifilmBankProperty) throws -> Self {
        let bytes = Array(payload)
        guard property == .name else {
            guard bytes.count == 2 else { throw LibraryError.invalid("PTP property must contain exactly two bytes") }
            return .word(UInt16(bytes[0]) | UInt16(bytes[1]) << 8)
        }
        guard let count = bytes.first, bytes.count == 1 + Int(count) * 2 else {
            throw LibraryError.invalid("invalid PTP bank-name length")
        }
        if count == 0 { return .name("") }
        guard bytes.suffix(2) == [0, 0] else { throw LibraryError.invalid("unterminated PTP bank name") }
        let units = stride(from: 1, to: bytes.count - 2, by: 2).map {
            UInt16(bytes[$0]) | UInt16(bytes[$0 + 1]) << 8
        }
        // PTP strings are UCS-2: reject embedded NULs and surrogate code units.
        guard units.allSatisfy({ $0 != 0 && !(0xD800...0xDFFF).contains($0) }) else {
            throw LibraryError.invalid("invalid PTP bank-name character")
        }
        return .name(String(decoding: units, as: UTF16.self))
    }

    /// Signed interpretation only; scaling and enum decoding are property-specific.
    public var signedWord: Int16? {
        guard case .word(let bits) = self else { return nil }
        return Int16(bitPattern: bits)
    }
}
