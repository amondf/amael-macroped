import Foundation

/// Wire format of the CH57x "MINI_KEYBOARD" configuration protocol (see docs/PROTOCOL.md).
public enum MacropedProtocol {
    public static let vendorIDs: [UInt16] = [0x1189, 0x514C]
    public static let productIDs: [UInt16] = [0x8840, 0x8842, 0x8830, 0x8831, 0x8832, 0x8833, 0x8850, 0x8851]

    public static let reportID: UInt8 = 0x03
    public static let reportLength = 65
    public static let recordLength = 50
    public static let maxChords = 18

    enum Marker {
        static let key: UInt8 = 0xFD
        static let led: UInt8 = 0xFE
        /// Records returned by the "read layer" command start with the command byte.
        static let readBack: UInt8 = 0xFA
        static let ledSlot: UInt8 = 0xB0
    }

    enum Kind {
        static let keyboard: UInt8 = 1
        static let media: UInt8 = 2
        static let mouse: UInt8 = 3
        static let led: UInt8 = 8
    }

    // MARK: Requests

    public static var identifyReport: [UInt8] { report([0xFB, 0xFB, 0xFB]) }
    public static var commitReport: [UInt8] { report([0xFD, 0xFE, 0xFF]) }

    public static func readLayerReport(layer: Int, keys: Int = 15, knobs: Int = 3) -> [UInt8] {
        report([0xFA, UInt8(keys), UInt8(knobs), UInt8(layer + 1)])
    }

    /// Wraps a payload into a 65-byte output report (Report ID + 64 bytes).
    public static func report(_ payload: [UInt8]) -> [UInt8] {
        precondition(payload.count <= reportLength - 1)
        var r = [UInt8](repeating: 0, count: reportLength)
        r[0] = reportID
        r.replaceSubrange(1..<(1 + payload.count), with: payload)
        return r
    }

    // MARK: Records

    /// 50-byte record binding `action` to `slot` on `layer` (0-based).
    public static func slotRecord(slot: Slot, layer: Int, action: KeyAction) -> [UInt8] {
        var r = [UInt8](repeating: 0, count: recordLength)
        r[0] = Marker.key
        r[1] = slot.code
        r[2] = UInt8(layer + 1)
        switch action {
        case .none:
            r[3] = Kind.keyboard
        case .keys(let chords):
            r[3] = Kind.keyboard
            let list = chords.prefix(maxChords)
            r[9] = UInt8(list.count)
            for (i, chord) in list.enumerated() {
                r[10 + 2 * i] = chord.modifiers.rawValue
                r[11 + 2 * i] = chord.keyCode
            }
        case .media(let key):
            r[3] = Kind.media
            r[9] = 2
            r[10] = UInt8(key.rawValue & 0xFF)
            r[11] = UInt8(key.rawValue >> 8)
        case .mouse(let m):
            let e = m.encoding
            r[3] = Kind.mouse
            r[9] = 1
            r[10] = e.modifiers
            r[11] = e.buttons
            r[14] = UInt8(bitPattern: e.wheel)
        }
        return r
    }

    public static func ledRecord(layer: Int, led: LEDConfig) -> [UInt8] {
        var r = [UInt8](repeating: 0, count: recordLength)
        r[0] = Marker.led
        r[1] = Marker.ledSlot
        r[2] = UInt8(layer + 1)
        r[3] = Kind.led
        r[9] = 1
        r[11] = (led.color.rawValue << 4) | (led.mode & 0x0F)
        return r
    }

    /// Every report needed to program `profile` (bindings, LED, commit per layer).
    /// Each inner array is one layer; the caller should pause ~1 s after each commit.
    public static func reports(for profile: DeviceProfile) -> [[[UInt8]]] {
        let slots = profile.layout.slots
        return profile.layers.prefix(DeviceProfile.layerCount).enumerated().map { layer, config in
            var out = slots.map { report(slotRecord(slot: $0, layer: layer, action: config[$0])) }
            if let led = config.led { out.append(report(ledRecord(layer: layer, led: led))) }
            out.append(commitReport)
            return out
        }
    }

    // MARK: Responses

    public enum Decoded: Equatable {
        case binding(layer: Int, slot: Slot, action: KeyAction)
        case led(layer: Int, config: LEDConfig)
    }

    /// Decodes a record read back from the device. Accepts input reports with or without the Report ID byte.
    public static func decode(_ bytes: [UInt8]) -> Decoded? {
        var r = bytes
        if r.first == reportID { r.removeFirst() }
        guard r.count >= 15, [Marker.key, Marker.led, Marker.readBack].contains(r[0]) else { return nil }
        let layer = Int(r[2]) - 1
        guard (0..<DeviceProfile.layerCount).contains(layer) else { return nil }

        if r[1] == Marker.ledSlot || r[3] == Kind.led {
            let v = r[11]
            return .led(layer: layer, config: LEDConfig(mode: v & 0x0F, color: LEDColor(rawValue: v >> 4) ?? .orange))
        }
        guard let slot = Slot(code: r[1]) else { return nil }
        let count = Int(r[9])
        switch r[3] {
        case Kind.keyboard:
            let n = min(count, maxChords, (r.count - 10) / 2)
            let chords = (0..<n).map { KeyChord(modifiers: Modifiers(rawValue: r[10 + 2 * $0]), keyCode: r[11 + 2 * $0]) }
            return .binding(layer: layer, slot: slot, action: chords.isEmpty ? .none : .keys(chords))
        case Kind.media:
            let code = UInt16(r[10]) | UInt16(r[11]) << 8
            return .binding(layer: layer, slot: slot, action: MediaKey(rawValue: code).map { .media($0) } ?? .none)
        case Kind.mouse:
            let wheel = Int8(bitPattern: r[14])
            let action = MouseAction.allCases.first {
                let e = $0.encoding
                return e.modifiers == r[10] && e.buttons == r[11] && e.wheel == wheel
            }
            return .binding(layer: layer, slot: slot, action: action.map { .mouse($0) } ?? .none)
        default:
            return .binding(layer: layer, slot: slot, action: .none)
        }
    }

    /// Parses the identify response: (keys, knobs).
    public static func decodeIdentify(_ bytes: [UInt8]) -> PadLayout? {
        // The vendor tool reads keys/knobs at [2]/[3] of a buffer that starts with the Report ID.
        let base = bytes.first == reportID ? 2 : 1
        guard bytes.count > base + 1 else { return nil }
        let keys = Int(bytes[base]), knobs = Int(bytes[base + 1])
        guard (1...15).contains(keys), (0...4).contains(knobs) else { return nil }
        return PadLayout(keys: keys, knobs: knobs)
    }
}
