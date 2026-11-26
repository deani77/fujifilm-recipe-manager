import Foundation

/// Library display units only. These are never converted to camera wire values.
public struct RecipeParameter: Identifiable {
    public let id: String
    public let label: String
    public let hint: String
    public let bounds: ClosedRange<Decimal>?
    public let step: Decimal?
    public init(_ id: String, _ label: String, _ hint: String, bounds: ClosedRange<Decimal>? = nil, step: Decimal? = nil) {
        self.id = id; self.label = label; self.hint = hint; self.bounds = bounds; self.step = step
    }
    public func parse(_ input: String) throws -> JSONValue? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        guard let bounds else { return .string(text) }
        // Decimal(string:) accepts partial numbers, so validate the entire input first.
        guard text.range(of: #"^-?[0-9]+(?:\.[0-9]+)?$"#, options: .regularExpression) != nil,
              let value = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")), bounds.contains(value) else {
            throw LibraryError.invalid("\(label): \(hint)")
        }
        if let step {
            let quotient = value / step
            var source = quotient
            var rounded = Decimal()
            NSDecimalRound(&rounded, &source, 0, .plain)
            guard quotient == rounded else { throw LibraryError.invalid("\(label): \(hint)") }
        }
        return .number(value)
    }
    public static let all: [RecipeParameter] = [
        .init("filmSimulation", "Film simulation", "e.g. Classic Chrome"),
        .init("dynamicRange", "Dynamic range", "e.g. DR100, DR200, DR400 or Auto"),
        .init("dynamicRangePriority", "D range priority", "e.g. Off, Weak, Strong or Auto"),
        .init("whiteBalance", "White balance", "e.g. Auto, Daylight or Color temperature"),
        .init("colorTemperature", "Color temperature (K)", "2500–10000, steps of 10", bounds: 2500...10000, step: 10),
        .init("wbShiftRed", "WB shift red", "−9 to +9, whole steps", bounds: -9...9, step: 1),
        .init("wbShiftBlue", "WB shift blue", "−9 to +9, whole steps", bounds: -9...9, step: 1),
        .init("highlight", "Highlight tone", "−2 to +4, half steps", bounds: -2...4, step: Decimal(string: "0.5")!),
        .init("shadow", "Shadow tone", "−2 to +4, half steps", bounds: -2...4, step: Decimal(string: "0.5")!),
        .init("color", "Color", "−4 to +4, whole steps", bounds: -4...4, step: 1),
        .init("sharpness", "Sharpness", "−4 to +4, whole steps", bounds: -4...4, step: 1),
        .init("highISONoiseReduction", "High ISO noise reduction", "−4 to +4, whole steps", bounds: -4...4, step: 1),
        .init("clarity", "Clarity", "−5 to +5, whole steps", bounds: -5...5, step: 1),
        .init("grainStrength", "Grain strength", "e.g. Off, Weak or Strong"),
        .init("grainSize", "Grain size", "e.g. Small or Large"),
        .init("colorChrome", "Color Chrome", "e.g. Off, Weak or Strong"),
        .init("colorChromeBlue", "Color Chrome FX Blue", "e.g. Off, Weak or Strong"),
        .init("exposureNotes", "Exposure guidance", "e.g. +1/3 to +2/3 EV")
    ]
}

extension JSONValue {
    public var displayText: String {
        switch self {
        case .string(let value): return value
        case .number(let value): return NSDecimalNumber(decimal: value).stringValue
        default: return "[Preserved JSON value]"
        }
    }
    public var isEditableScalar: Bool {
        switch self { case .string, .number: return true; default: return false }
    }
}
