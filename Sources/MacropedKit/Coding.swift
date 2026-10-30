import Foundation

// Human-editable JSON for profiles:
//   slot:   "K1"…"K15", "knob1.left", "knob1.press", "knob1.right"
//   action: {"keys": [{"modifiers": 8, "keyCode": 6}]} | {"media": "volumeUp"} | {"mouse": "leftClick"} | {}

extension Slot {
    public var identifier: String {
        switch self {
        case .key(let n): return "K\(n)"
        case .knobLeft(let k): return "knob\(k + 1).left"
        case .knobPress(let k): return "knob\(k + 1).press"
        case .knobRight(let k): return "knob\(k + 1).right"
        }
    }

    public init?(identifier: String) {
        let s = identifier.lowercased()
        if s.hasPrefix("k"), !s.hasPrefix("knob"), let n = Int(s.dropFirst()), (1...15).contains(n) {
            self = .key(n)
            return
        }
        let parts = s.split(separator: ".")
        guard parts.count == 2, parts[0].hasPrefix("knob"), let k = Int(parts[0].dropFirst(4)), (1...4).contains(k) else {
            return nil
        }
        switch parts[1] {
        case "left": self = .knobLeft(k - 1)
        case "press": self = .knobPress(k - 1)
        case "right": self = .knobRight(k - 1)
        default: return nil
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = try c.decode(String.self)
        guard let slot = Slot(identifier: raw) else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Slot inválido: \(raw)")
        }
        self = slot
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(identifier)
    }
}

extension MediaKey {
    public var identifier: String { String(describing: self) }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let code = try? c.decode(UInt16.self), let key = MediaKey(rawValue: code) {
            self = key
            return
        }
        let raw = try c.decode(String.self)
        guard let key = MediaKey.allCases.first(where: { $0.identifier == raw }) else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Tecla multimídia inválida: \(raw)")
        }
        self = key
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(identifier)
    }
}

extension KeyAction {
    private enum Keys: String, CodingKey { case keys, media, mouse }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        if let chords = try c.decodeIfPresent([KeyChord].self, forKey: .keys) {
            self = .keys(chords)
        } else if let media = try c.decodeIfPresent(MediaKey.self, forKey: .media) {
            self = .media(media)
        } else if let mouse = try c.decodeIfPresent(MouseAction.self, forKey: .mouse) {
            self = .mouse(mouse)
        } else {
            self = .none
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .none: break
        case .keys(let chords): try c.encode(chords, forKey: .keys)
        case .media(let m): try c.encode(m, forKey: .media)
        case .mouse(let m): try c.encode(m, forKey: .mouse)
        }
    }
}
