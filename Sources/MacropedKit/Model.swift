import Foundation

/// HID keyboard modifier bitmask (same layout as the boot keyboard report).
public struct Modifiers: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let control = Modifiers(rawValue: 0x01)
    public static let shift = Modifiers(rawValue: 0x02)
    public static let option = Modifiers(rawValue: 0x04)
    public static let command = Modifiers(rawValue: 0x08)
    public static let rightControl = Modifiers(rawValue: 0x10)
    public static let rightShift = Modifiers(rawValue: 0x20)
    public static let rightOption = Modifiers(rawValue: 0x40)
    public static let rightCommand = Modifiers(rawValue: 0x80)

    /// Human readable symbols in macOS order (⌃⌥⇧⌘).
    public var symbols: String {
        var s = ""
        if contains(.control) || contains(.rightControl) { s += "⌃" }
        if contains(.option) || contains(.rightOption) { s += "⌥" }
        if contains(.shift) || contains(.rightShift) { s += "⇧" }
        if contains(.command) || contains(.rightCommand) { s += "⌘" }
        return s
    }
}

/// One key press: modifiers held + a HID keyboard usage (page 0x07). `keyCode == 0` means modifiers only.
public struct KeyChord: Codable, Hashable, Sendable {
    public var modifiers: Modifiers
    public var keyCode: UInt8

    public init(modifiers: Modifiers = [], keyCode: UInt8) {
        self.modifiers = modifiers
        self.keyCode = keyCode
    }

    public var displayName: String {
        modifiers.symbols + (keyCode == 0 ? "" : HIDKeys.name(for: keyCode))
    }
}

/// Consumer-page (multimedia) codes exposed by the original vendor tool.
public enum MediaKey: UInt16, CaseIterable, Codable, Sendable {
    case playPause = 0x00CD
    case stop = 0x00B7
    case previousTrack = 0x00B6
    case nextTrack = 0x00B5
    case mute = 0x00E2
    case volumeUp = 0x00E9
    case volumeDown = 0x00EA
    case brightnessUp = 0x006F
    case brightnessDown = 0x0070
    case myComputer = 0x0194
    case mediaPlayer = 0x0183
    case calculator = 0x0192
    case browserHome = 0x0223
    case email = 0x018A
    case bassUp = 0x0152
    case bassDown = 0x0153
    case trebleUp = 0x0154
    case trebleDown = 0x0155
    case browserRefresh = 0x0227
    case browserForward = 0x0225
    case browserBack = 0x0224

    public var displayName: String {
        switch self {
        case .playPause: return "Play / Pause"
        case .stop: return "Parar"
        case .previousTrack: return "Faixa anterior"
        case .nextTrack: return "Próxima faixa"
        case .mute: return "Mudo"
        case .volumeUp: return "Volume +"
        case .volumeDown: return "Volume −"
        case .brightnessUp: return "Brilho +"
        case .brightnessDown: return "Brilho −"
        case .myComputer: return "Meu computador"
        case .mediaPlayer: return "Player de mídia"
        case .calculator: return "Calculadora"
        case .browserHome: return "Navegador (início)"
        case .email: return "E-mail"
        case .bassUp: return "Grave +"
        case .bassDown: return "Grave −"
        case .trebleUp: return "Agudo +"
        case .trebleDown: return "Agudo −"
        case .browserRefresh: return "Atualizar página"
        case .browserForward: return "Avançar página"
        case .browserBack: return "Voltar página"
        }
    }
}

public enum MouseAction: String, CaseIterable, Codable, Sendable {
    case leftClick, middleClick, rightClick
    case wheelUp, wheelDown
    case controlWheelUp, controlWheelDown
    case shiftWheelUp, shiftWheelDown
    case optionWheelUp, optionWheelDown

    /// (keyboard modifiers, button mask, wheel delta) as stored in the slot record.
    public var encoding: (modifiers: UInt8, buttons: UInt8, wheel: Int8) {
        switch self {
        case .leftClick: return (0, 0x01, 0)
        case .middleClick: return (0, 0x04, 0)
        case .rightClick: return (0, 0x02, 0)
        case .wheelUp: return (0, 0, 1)
        case .wheelDown: return (0, 0, -1)
        case .controlWheelUp: return (0x01, 0, 1)
        case .controlWheelDown: return (0x01, 0, -1)
        case .shiftWheelUp: return (0x02, 0, 1)
        case .shiftWheelDown: return (0x02, 0, -1)
        case .optionWheelUp: return (0x04, 0, 1)
        case .optionWheelDown: return (0x04, 0, -1)
        }
    }

    public var displayName: String {
        switch self {
        case .leftClick: return "Clique esquerdo"
        case .middleClick: return "Clique do meio"
        case .rightClick: return "Clique direito"
        case .wheelUp: return "Rolar para cima"
        case .wheelDown: return "Rolar para baixo"
        case .controlWheelUp: return "⌃ + rolar para cima"
        case .controlWheelDown: return "⌃ + rolar para baixo"
        case .shiftWheelUp: return "⇧ + rolar para cima"
        case .shiftWheelDown: return "⇧ + rolar para baixo"
        case .optionWheelUp: return "⌥ + rolar para cima"
        case .optionWheelDown: return "⌥ + rolar para baixo"
        }
    }
}

/// What a key / knob direction does.
public enum KeyAction: Codable, Hashable, Sendable {
    case none
    /// Sequence of up to `MacropedProtocol.maxChords` key presses.
    case keys([KeyChord])
    case media(MediaKey)
    case mouse(MouseAction)

    public var summary: String {
        switch self {
        case .none: return "—"
        case .keys(let chords): return chords.isEmpty ? "—" : chords.map(\.displayName).joined(separator: " ")
        case .media(let m): return m.displayName
        case .mouse(let m): return m.displayName
        }
    }
}

public enum LEDColor: UInt8, CaseIterable, Codable, Sendable {
    case red = 1, orange, yellow, green, cyan, blue, purple

    public var displayName: String {
        switch self {
        case .red: return "Vermelho"
        case .orange: return "Laranja"
        case .yellow: return "Amarelo"
        case .green: return "Verde"
        case .cyan: return "Ciano"
        case .blue: return "Azul"
        case .purple: return "Roxo"
        }
    }
}

public struct LEDConfig: Codable, Hashable, Sendable {
    /// Firmware effect 0...5 (0 = off).
    public var mode: UInt8
    public var color: LEDColor

    public init(mode: UInt8, color: LEDColor) {
        self.mode = min(mode, 5)
        self.color = color
    }
}

/// A programmable input on the pad.
public enum Slot: Hashable, Codable, Sendable, Comparable {
    /// Key number 1...15.
    case key(Int)
    /// Knob index 0...3, rotated counter-clockwise.
    case knobLeft(Int)
    case knobPress(Int)
    /// Knob index 0...3, rotated clockwise.
    case knobRight(Int)

    public var code: UInt8 {
        switch self {
        case .key(let n): return UInt8(n)
        case .knobLeft(let k): return UInt8(0x10 + 3 * k)
        case .knobPress(let k): return UInt8(0x11 + 3 * k)
        case .knobRight(let k): return UInt8(0x12 + 3 * k)
        }
    }

    public init?(code: UInt8) {
        switch code {
        case 0x01...0x0F: self = .key(Int(code))
        case 0x10...0x1B:
            let k = Int(code - 0x10) / 3
            switch (code - 0x10) % 3 {
            case 0: self = .knobLeft(k)
            case 1: self = .knobPress(k)
            default: self = .knobRight(k)
            }
        default: return nil
        }
    }

    public var displayName: String {
        switch self {
        case .key(let n): return "Tecla \(n)"
        case .knobLeft(let k): return "Knob \(k + 1) ↺ esquerda"
        case .knobPress(let k): return "Knob \(k + 1) ● pressionar"
        case .knobRight(let k): return "Knob \(k + 1) ↻ direita"
        }
    }

    public static func < (lhs: Slot, rhs: Slot) -> Bool { lhs.code < rhs.code }
}

public struct SlotBinding: Codable, Hashable, Sendable {
    public var slot: Slot
    public var action: KeyAction
    public init(slot: Slot, action: KeyAction) {
        self.slot = slot
        self.action = action
    }
}

public struct LayerConfig: Codable, Hashable, Sendable {
    public var bindings: [SlotBinding]
    public var led: LEDConfig?

    public init(bindings: [SlotBinding] = [], led: LEDConfig? = nil) {
        self.bindings = bindings
        self.led = led
    }

    public subscript(slot: Slot) -> KeyAction {
        get { bindings.first { $0.slot == slot }?.action ?? .none }
        set {
            if let i = bindings.firstIndex(where: { $0.slot == slot }) {
                bindings[i].action = newValue
            } else {
                bindings.append(SlotBinding(slot: slot, action: newValue))
                bindings.sort { $0.slot < $1.slot }
            }
        }
    }
}

/// Physical layout of the pad (the firmware reports it on identify).
public struct PadLayout: Codable, Hashable, Sendable {
    public var keys: Int
    public var knobs: Int

    public init(keys: Int, knobs: Int) {
        self.keys = max(1, min(keys, 15))
        self.knobs = max(0, min(knobs, 4))
    }

    /// 3 keys + 1 knob (the most common "Macroped mini" variant).
    public static let threeKeysOneKnob = PadLayout(keys: 3, knobs: 1)

    public var slots: [Slot] {
        (1...keys).map { Slot.key($0) }
            + (0..<knobs).flatMap { [Slot.knobLeft($0), .knobPress($0), .knobRight($0)] }
    }
}

public struct DeviceProfile: Codable, Hashable, Sendable {
    public static let layerCount = 3

    public var name: String
    public var layout: PadLayout
    public var layers: [LayerConfig]

    public init(name: String = "Perfil", layout: PadLayout = .threeKeysOneKnob, layers: [LayerConfig]? = nil) {
        self.name = name
        self.layout = layout
        self.layers = layers ?? Array(repeating: LayerConfig(), count: Self.layerCount)
    }

    /// Sensible starting point: copy/paste/undo on keys, volume on the knob.
    public static func defaultProfile(layout: PadLayout = .threeKeysOneKnob) -> DeviceProfile {
        var p = DeviceProfile(name: "Padrão", layout: layout)
        var l = LayerConfig(led: LEDConfig(mode: 1, color: .orange))
        l[.key(1)] = .keys([KeyChord(modifiers: .command, keyCode: HIDKeys.c)])
        l[.key(2)] = .keys([KeyChord(modifiers: .command, keyCode: HIDKeys.v)])
        l[.key(3)] = .keys([KeyChord(modifiers: .command, keyCode: HIDKeys.z)])
        if layout.knobs > 0 {
            l[.knobLeft(0)] = .media(.volumeDown)
            l[.knobPress(0)] = .media(.mute)
            l[.knobRight(0)] = .media(.volumeUp)
        }
        p.layers[0] = l
        return p
    }
}
