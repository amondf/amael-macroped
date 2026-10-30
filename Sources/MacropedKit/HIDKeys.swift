import Foundation

/// HID Keyboard/Keypad page (0x07) usages supported by the firmware.
public enum HIDKeys {
    public static let a: UInt8 = 0x04
    public static let c: UInt8 = 0x06
    public static let v: UInt8 = 0x19
    public static let z: UInt8 = 0x1D

    public struct Entry: Hashable, Sendable, Identifiable {
        public let code: UInt8
        public let name: String
        public let group: String
        public var id: UInt8 { code }
    }

    public static let all: [Entry] = {
        var e: [Entry] = []
        func add(_ group: String, _ items: [(UInt8, String)]) {
            e += items.map { Entry(code: $0.0, name: $0.1, group: group) }
        }
        add("Letras", (0..<26).map { (UInt8(0x04 + $0), String(UnicodeScalar(UInt8(65 + $0)))) })
        add("Números", [(0x1E, "1"), (0x1F, "2"), (0x20, "3"), (0x21, "4"), (0x22, "5"),
                        (0x23, "6"), (0x24, "7"), (0x25, "8"), (0x26, "9"), (0x27, "0")])
        add("Especiais", [(0x28, "Return ↩"), (0x29, "Esc"), (0x2A, "Backspace ⌫"), (0x2B, "Tab ⇥"),
                          (0x2C, "Espaço"), (0x39, "Caps Lock"), (0x65, "Menu")])
        add("Símbolos", [(0x2D, "- _"), (0x2E, "= +"), (0x2F, "[ {"), (0x30, "] }"), (0x31, "\\ |"),
                         (0x32, "# ~ (ISO)"), (0x33, "; :"), (0x34, "' \""), (0x35, "` ~"),
                         (0x36, ", <"), (0x37, ". >"), (0x38, "/ ?"), (0x64, "\\ | (ISO)")])
        add("Navegação", [(0x4F, "→"), (0x50, "←"), (0x51, "↓"), (0x52, "↑"),
                          (0x4A, "Home"), (0x4D, "End"), (0x4B, "Page Up"), (0x4E, "Page Down"),
                          (0x49, "Insert"), (0x4C, "Delete ⌦"), (0x46, "Print Screen"),
                          (0x47, "Scroll Lock"), (0x48, "Pause")])
        add("Função", (0..<12).map { (UInt8(0x3A + $0), "F\($0 + 1)") }
            + (0..<12).map { (UInt8(0x68 + $0), "F\($0 + 13)") })
        add("Teclado numérico", [(0x53, "Num Lock"), (0x54, "Num /"), (0x55, "Num *"), (0x56, "Num -"),
                                 (0x57, "Num +"), (0x58, "Num Enter"), (0x59, "Num 1"), (0x5A, "Num 2"),
                                 (0x5B, "Num 3"), (0x5C, "Num 4"), (0x5D, "Num 5"), (0x5E, "Num 6"),
                                 (0x5F, "Num 7"), (0x60, "Num 8"), (0x61, "Num 9"), (0x62, "Num 0"),
                                 (0x63, "Num .")])
        return e
    }()

    public static let groups: [String] = {
        var seen = Set<String>()
        return all.compactMap { seen.insert($0.group).inserted ? $0.group : nil }
    }()

    private static let byCode: [UInt8: Entry] = Dictionary(all.map { ($0.code, $0) }, uniquingKeysWith: { a, _ in a })

    public static func name(for code: UInt8) -> String {
        byCode[code]?.name ?? String(format: "0x%02X", code)
    }

    /// macOS virtual key code (kVK_*) → HID usage, for "record shortcut".
    public static let fromMacKeyCode: [UInt16: UInt8] = [
        0x00: 0x04, 0x0B: 0x05, 0x08: 0x06, 0x02: 0x07, 0x0E: 0x08, 0x03: 0x09, 0x05: 0x0A, 0x04: 0x0B,
        0x22: 0x0C, 0x26: 0x0D, 0x28: 0x0E, 0x25: 0x0F, 0x2E: 0x10, 0x2D: 0x11, 0x1F: 0x12, 0x23: 0x13,
        0x0C: 0x14, 0x0F: 0x15, 0x01: 0x16, 0x11: 0x17, 0x20: 0x18, 0x09: 0x19, 0x0D: 0x1A, 0x07: 0x1B,
        0x10: 0x1C, 0x06: 0x1D,
        0x12: 0x1E, 0x13: 0x1F, 0x14: 0x20, 0x15: 0x21, 0x17: 0x22, 0x16: 0x23, 0x1A: 0x24, 0x1C: 0x25,
        0x19: 0x26, 0x1D: 0x27,
        0x24: 0x28, 0x35: 0x29, 0x33: 0x2A, 0x30: 0x2B, 0x31: 0x2C, 0x1B: 0x2D, 0x18: 0x2E, 0x21: 0x2F,
        0x1E: 0x30, 0x2A: 0x31, 0x29: 0x33, 0x27: 0x34, 0x32: 0x35, 0x2B: 0x36, 0x2F: 0x37, 0x2C: 0x38,
        0x0A: 0x64, 0x39: 0x39,
        0x7A: 0x3A, 0x78: 0x3B, 0x63: 0x3C, 0x76: 0x3D, 0x60: 0x3E, 0x61: 0x3F, 0x62: 0x40, 0x64: 0x41,
        0x65: 0x42, 0x6D: 0x43, 0x67: 0x44, 0x6F: 0x45, 0x69: 0x68, 0x6B: 0x69, 0x71: 0x6A, 0x6A: 0x6B,
        0x40: 0x6C, 0x4F: 0x6D, 0x50: 0x6E, 0x5A: 0x6F,
        0x7C: 0x4F, 0x7B: 0x50, 0x7D: 0x51, 0x7E: 0x52, 0x73: 0x4A, 0x77: 0x4D, 0x74: 0x4B, 0x79: 0x4E,
        0x75: 0x4C, 0x72: 0x49,
        0x47: 0x53, 0x4B: 0x54, 0x43: 0x55, 0x4E: 0x56, 0x45: 0x57, 0x4C: 0x58, 0x53: 0x59, 0x54: 0x5A,
        0x55: 0x5B, 0x56: 0x5C, 0x57: 0x5D, 0x58: 0x5E, 0x59: 0x5F, 0x5B: 0x60, 0x5C: 0x61, 0x52: 0x62,
        0x41: 0x63,
    ]

    /// Converts printable ASCII text into key presses assuming a US (ANSI) host layout.
    /// Returns nil when a character cannot be typed.
    public static func chords(forText text: String) -> [KeyChord]? {
        var out: [KeyChord] = []
        for ch in text {
            guard let c = asciiMap[ch] else { return nil }
            out.append(KeyChord(modifiers: c.1 ? .shift : [], keyCode: c.0))
        }
        return out
    }

    private static let asciiMap: [Character: (UInt8, Bool)] = {
        var m: [Character: (UInt8, Bool)] = [:]
        for i in 0..<26 {
            m[Character(UnicodeScalar(UInt8(97 + i)))] = (UInt8(0x04 + i), false)
            m[Character(UnicodeScalar(UInt8(65 + i)))] = (UInt8(0x04 + i), true)
        }
        let digits = Array("1234567890"), shifted = Array("!@#$%^&*()")
        for i in 0..<10 {
            m[digits[i]] = (UInt8(0x1E + i), false)
            m[shifted[i]] = (UInt8(0x1E + i), true)
        }
        let pairs: [(Character, Character, UInt8)] = [
            ("-", "_", 0x2D), ("=", "+", 0x2E), ("[", "{", 0x2F), ("]", "}", 0x30), ("\\", "|", 0x31),
            (";", ":", 0x33), ("'", "\"", 0x34), ("`", "~", 0x35), (",", "<", 0x36), (".", ">", 0x37),
            ("/", "?", 0x38),
        ]
        for (plain, shift, code) in pairs {
            m[plain] = (code, false)
            m[shift] = (code, true)
        }
        m[" "] = (0x2C, false)
        m["\n"] = (0x28, false)
        m["\t"] = (0x2B, false)
        return m
    }()
}
