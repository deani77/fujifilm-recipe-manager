import Foundation

public enum CameraRecipeDocument {
    /// Display mappings are provisional; raw payloads are always retained alongside them.
    /// Derived from the attributed encoding tables linked in docs/USB_PROTOCOL.md.
    public static func make(identity: CameraIdentity, banks: [CameraBankSnapshot]) throws -> RecipeDocument {
        var document = RecipeDocument()
        document.metadata["cameraImportNotice"] = .string("Experimental C1–C4 recipe import; not a complete camera backup. Custom WB calibration and other WB modes' shifts are not captured. Display mappings need comparison with the camera menus.")
        for bank in banks {
            guard let data = bank.values[.name], case .name(let name) = try FujifilmPropertyValue.decode(data, for: .name) else {
                throw CameraImportError.invalid("Missing bank name")
            }
            var recipe = Recipe(name: name.isEmpty ? "X-M5 C\(bank.bank)" : name)
            var raw: [String: JSONValue] = [:]
            for (property, data) in bank.values {
                raw[String(format: "0x%04X", property.rawValue)] = .string(data.map { String(format: "%02X", $0) }.joined())
            }
            var fields = recipe.fields
            fields["cameraImport"] = .object([
                "model": .string(identity.model), "firmware": .string(identity.firmware),
                "bank": .number(Decimal(bank.bank)), "importedAt": .string(ISO8601DateFormatter().string(from: Date())),
                "selectorRestored": .bool(true), "rawPropertiesLEHex": .object(raw),
                "unsupportedProperties": .array(bank.unsupported.map { .string(String(format: "0x%04X", $0)) })
            ])
            recipe = try Recipe(fields: fields)
            func word(_ property: FujifilmBankProperty) -> UInt16? {
                guard let data = bank.values[property], case .word(let n) = try? FujifilmPropertyValue.decode(data, for: property) else { return nil }
                return n
            }
            func text(_ property: FujifilmBankProperty, _ key: String, _ table: [UInt16: String]) {
                if let n = word(property), let label = table[n] { recipe.parameters[key] = .string(label) }
            }
            func scaled(_ property: FujifilmBankProperty, _ key: String, divisor: Decimal = 1) {
                guard let n = word(property) else { return }
                let value = Decimal(Int(Int16(bitPattern: n))) / divisor
                // Unknown/sentinel/out-of-menu values stay in rawPropertiesLEHex only.
                guard let spec = RecipeParameter.all.first(where: { $0.id == key }),
                      let parsed = try? spec.parse(NSDecimalNumber(decimal: value).stringValue) else { return }
                recipe.parameters[key] = parsed
            }
            text(.filmSimulation, "filmSimulation", [1:"Provia",2:"Velvia",3:"Astia",4:"Pro Neg. Hi",5:"Pro Neg. Std",6:"Monochrome",7:"Monochrome + Ye",8:"Monochrome + R",9:"Monochrome + G",10:"Sepia",11:"Classic Chrome",12:"Acros",13:"Acros + Ye",14:"Acros + R",15:"Acros + G",16:"Eterna",17:"Classic Neg.",18:"Eterna Bleach Bypass",19:"Nostalgic Neg.",20:"Reala Ace"])
            text(.dynamicRange, "dynamicRange", [100:"DR100",200:"DR200",400:"DR400",65535:"Auto"])
            text(.dynamicRangePriority, "dynamicRangePriority", [0:"Off",1:"Weak",2:"Strong",0x8000:"Auto"])
            text(.whiteBalance, "whiteBalance", [2:"Auto",4:"Daylight",6:"Incandescent",8:"Underwater",0x8001:"Fluorescent 1",0x8002:"Fluorescent 2",0x8003:"Fluorescent 3",0x8006:"Shade",0x8007:"Color temperature",0x8008:"Custom 1",0x8009:"Custom 2",0x800A:"Custom 3",0x8020:"Auto White Priority",0x8021:"Auto Ambience Priority"])
            if word(.whiteBalance) == 0x8007 { scaled(.kelvin, "colorTemperature") }
            scaled(.wbShiftRed, "wbShiftRed"); scaled(.wbShiftBlue, "wbShiftBlue")
            for (property, key) in [(FujifilmBankProperty.highlight,"highlight"),(.shadow,"shadow"),(.color,"color"),(.sharpness,"sharpness"),(.clarity,"clarity")] {
                scaled(property, key, divisor: 10)
            }
            let nr: [UInt16: Int] = [0x8000:-4,0x7000:-3,0x4000:-2,0x3000:-1,0x2000:0,0x1000:1,0:2,0x6000:3,0x5000:4]
            if let n = word(.highISONoiseReduction), let value = nr[n] { recipe.parameters["highISONoiseReduction"] = .number(Decimal(value)) }
            text(.grain,"grainStrength",[1:"Off",2:"Weak",3:"Strong",4:"Weak",5:"Strong",6:"Off",7:"Off"])
            text(.grain,"grainSize",[2:"Small",3:"Small",4:"Large",5:"Large",6:"Small",7:"Large"])
            text(.colorChrome,"colorChrome",[1:"Off",2:"Weak",3:"Strong"])
            text(.colorChromeBlue,"colorChromeBlue",[1:"Off",2:"Weak",3:"Strong"])
            recipe[text: "notes"] = "Imported from X-M5 C\(bank.bank). Compare these provisional display values with the camera menus. Raw values are retained in the JSON export. This is not a full settings backup."
            document.recipes.append(recipe)
        }
        try document.validate()
        return document
    }
}
