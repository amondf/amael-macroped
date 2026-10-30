import XCTest
@testable import MacropedKit

final class ProtocolTests: XCTestCase {
    func testReportFraming() {
        let r = MacropedProtocol.commitReport
        XCTAssertEqual(r.count, 65)
        XCTAssertEqual(Array(r[0...3]), [0x03, 0xFD, 0xFE, 0xFF])
        XCTAssertTrue(r[4...].allSatisfy { $0 == 0 })
        XCTAssertEqual(Array(MacropedProtocol.identifyReport[0...3]), [0x03, 0xFB, 0xFB, 0xFB])
        XCTAssertEqual(Array(MacropedProtocol.readLayerReport(layer: 1)[0...4]), [0x03, 0xFA, 0x0F, 0x03, 0x02])
    }

    func testSlotCodes() {
        XCTAssertEqual(Slot.key(1).code, 0x01)
        XCTAssertEqual(Slot.key(15).code, 0x0F)
        XCTAssertEqual(Slot.knobLeft(0).code, 0x10)
        XCTAssertEqual(Slot.knobPress(0).code, 0x11)
        XCTAssertEqual(Slot.knobRight(0).code, 0x12)
        XCTAssertEqual(Slot.knobRight(3).code, 0x1B)
        for code in UInt8(1)...0x1B { XCTAssertEqual(Slot(code: code)?.code, code) }
        XCTAssertNil(Slot(code: 0))
        XCTAssertNil(Slot(code: 0x1C))
    }

    func testKeyboardRecord() {
        let action = KeyAction.keys([
            KeyChord(modifiers: [.command, .shift], keyCode: 0x21),
            KeyChord(keyCode: 0x28),
        ])
        let r = MacropedProtocol.slotRecord(slot: .key(2), layer: 0, action: action)
        XCTAssertEqual(r.count, 50)
        XCTAssertEqual(Array(r[0...13]), [0xFD, 0x02, 0x01, 0x01, 0, 0, 0, 0, 0, 0x02, 0x0A, 0x21, 0x00, 0x28])
        XCTAssertTrue(r[14...].allSatisfy { $0 == 0 })
    }

    func testChordLimit() {
        let many = KeyAction.keys(Array(repeating: KeyChord(keyCode: 0x04), count: 30))
        let r = MacropedProtocol.slotRecord(slot: .key(1), layer: 0, action: many)
        XCTAssertEqual(r[9], UInt8(MacropedProtocol.maxChords))
        XCTAssertEqual(r.count, 50)
    }

    func testMediaRecord() {
        let r = MacropedProtocol.slotRecord(slot: .knobRight(0), layer: 2, action: .media(.volumeUp))
        XCTAssertEqual(Array(r[0...11]), [0xFD, 0x12, 0x03, 0x02, 0, 0, 0, 0, 0, 0x02, 0xE9, 0x00])
        let calc = MacropedProtocol.slotRecord(slot: .key(1), layer: 0, action: .media(.calculator))
        XCTAssertEqual(Array(calc[10...11]), [0x92, 0x01])
    }

    func testMouseRecord() {
        let r = MacropedProtocol.slotRecord(slot: .knobLeft(0), layer: 0, action: .mouse(.controlWheelDown))
        XCTAssertEqual(Array(r[0...14]), [0xFD, 0x10, 0x01, 0x03, 0, 0, 0, 0, 0, 0x01, 0x01, 0x00, 0, 0, 0xFF])
        let click = MacropedProtocol.slotRecord(slot: .key(3), layer: 0, action: .mouse(.middleClick))
        XCTAssertEqual(click[11], 0x04)
    }

    func testLEDRecord() {
        let r = MacropedProtocol.ledRecord(layer: 0, led: LEDConfig(mode: 3, color: .cyan))
        XCTAssertEqual(Array(r[0...11]), [0xFE, 0xB0, 0x01, 0x08, 0, 0, 0, 0, 0, 0x01, 0x00, 0x53])
    }

    func testRoundTrip() {
        let actions: [KeyAction] = [
            .keys([KeyChord(modifiers: .control, keyCode: 0x06)]),
            .media(.mute),
            .mouse(.shiftWheelUp),
            .none,
        ]
        for (i, action) in actions.enumerated() {
            let slot = Slot.key(i + 1)
            let rec = MacropedProtocol.report(MacropedProtocol.slotRecord(slot: slot, layer: 1, action: action))
            XCTAssertEqual(MacropedProtocol.decode(rec), .binding(layer: 1, slot: slot, action: action))
        }
        let led = LEDConfig(mode: 2, color: .purple)
        XCTAssertEqual(MacropedProtocol.decode(MacropedProtocol.ledRecord(layer: 2, led: led)), .led(layer: 2, config: led))
    }

    func testProfileReports() {
        let reports = MacropedProtocol.reports(for: .defaultProfile())
        XCTAssertEqual(reports.count, 3)
        // 3 keys + 3 knob slots + LED + commit on layer 1; 6 slots + commit on the others.
        XCTAssertEqual(reports.map(\.count), [8, 7, 7])
        XCTAssertTrue(reports.allSatisfy { $0.last == MacropedProtocol.commitReport })
        XCTAssertTrue(reports.joined().allSatisfy { $0.count == 65 && $0[0] == 0x03 })
    }

    /// Bytes captured from a real 514C:8851 (3 keys + 1 knob) answering `03 FA 0F 03 01`.
    func testDecodeRealReadBack() {
        func pad(_ b: [UInt8]) -> [UInt8] { b + [UInt8](repeating: 0, count: 64 - b.count) }
        XCTAssertEqual(MacropedProtocol.decode(pad([0x03, 0xFA, 0x01, 0x01, 0x01, 0, 0, 0, 0, 0, 0x01, 0x01, 0x50])),
                       .binding(layer: 0, slot: .key(1), action: .keys([KeyChord(modifiers: .control, keyCode: 0x50)])))
        XCTAssertEqual(MacropedProtocol.decode(pad([0x03, 0xFA, 0x10, 0x01, 0x02, 0, 0, 0, 0, 0, 0x01, 0xEA, 0x00])),
                       .binding(layer: 0, slot: .knobLeft(0), action: .media(.volumeDown)))
        XCTAssertEqual(MacropedProtocol.decodeIdentify(pad([0x03, 0xFB, 0x03, 0x01])), PadLayout(keys: 3, knobs: 1))
    }

    func testIdentifyDecoding() {
        XCTAssertEqual(MacropedProtocol.decodeIdentify([0x03, 0xFB, 3, 1, 0]), PadLayout(keys: 3, knobs: 1))
        XCTAssertNil(MacropedProtocol.decodeIdentify([0x03, 0xFB, 0, 0]))
    }

    func testTextToChords() {
        let c = HIDKeys.chords(forText: "Hi!")
        XCTAssertEqual(c, [
            KeyChord(modifiers: .shift, keyCode: 0x0B),
            KeyChord(keyCode: 0x0C),
            KeyChord(modifiers: .shift, keyCode: 0x1E),
        ])
        XCTAssertNil(HIDKeys.chords(forText: "ç"))
    }

    func testProfileCodable() throws {
        let p = DeviceProfile.defaultProfile()
        let back = try JSONDecoder().decode(DeviceProfile.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(p, back)
    }
}
