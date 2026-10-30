import Foundation
import IOKit
import IOKit.hid

public struct MacropedDeviceInfo: Hashable, Sendable, CustomStringConvertible {
    public let vendorID: UInt16
    public let productID: UInt16
    public let product: String
    public let manufacturer: String
    public let usagePage: Int
    public let usage: Int
    public let maxOutputReportSize: Int
    public let maxInputReportSize: Int
    public let locationID: Int
    public let registryID: UInt64

    /// Score used to pick the configuration interface among the composite device's HID interfaces.
    var configScore: Int {
        var s = 0
        if maxOutputReportSize >= 64 { s += 4 }
        if usagePage >= 0xFF00 { s += 2 }
        if maxInputReportSize >= 64 { s += 1 }
        return s
    }

    public var description: String {
        String(format: "%@ [%04X:%04X] usagePage=0x%04X usage=0x%02X out=%d in=%d loc=0x%08X",
               product, vendorID, productID, usagePage, usage, maxOutputReportSize, maxInputReportSize, locationID)
    }
}

public enum MacropedError: LocalizedError, Equatable {
    case notFound
    case permissionDenied
    case openFailed(Int32)
    case writeFailed(Int32)

    public var errorDescription: String? {
        switch self {
        case .notFound:
            return "Mini teclado não encontrado. Verifique o cabo USB (precisa ser de dados) e se o macOS permitiu o acessório."
        case .permissionDenied:
            return "O macOS negou acesso ao dispositivo. Libere o app em Ajustes do Sistema › Privacidade e Segurança › Monitoramento de Entrada."
        case .openFailed(let r):
            return String(format: "Falha ao abrir o dispositivo (IOReturn 0x%08X).", UInt32(bitPattern: r))
        case .writeFailed(let r):
            return String(format: "Falha ao enviar dados ao dispositivo (IOReturn 0x%08X).", UInt32(bitPattern: r))
        }
    }
}

/// Native (IOKit) connection to the macropad's configuration interface.
public final class MacropedDevice: @unchecked Sendable {
    public let info: MacropedDeviceInfo
    private let device: IOHIDDevice
    private let thread: HIDRunLoopThread
    private let inputBuffer: UnsafeMutablePointer<UInt8>
    private let inputBufferSize = 256

    private let lock = NSLock()
    private var queue: [[UInt8]] = []
    private let available = DispatchSemaphore(value: 0)
    private var isOpen = false

    /// Delay after each layer commit (the vendor tool waits 1 s while the MCU writes flash).
    public var commitDelay: TimeInterval = 1.0

    // MARK: Discovery

    public static func list() -> [MacropedDeviceInfo] {
        devices().map(\.info).sorted { $0.configScore > $1.configScore }
    }

    /// Opens the best matching configuration interface.
    public static func open(_ preferred: MacropedDeviceInfo? = nil) throws -> MacropedDevice {
        let found = devices().sorted { $0.info.configScore > $1.info.configScore }
        let pick = preferred.flatMap { p in found.first { $0.info.registryID == p.registryID } } ?? found.first
        guard let pick else { throw MacropedError.notFound }
        return try MacropedDevice(device: pick.device, info: pick.info)
    }

    private static func devices() -> [(device: IOHIDDevice, info: MacropedDeviceInfo)] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching = MacropedProtocol.vendorIDs.map { [kIOHIDVendorIDKey: Int($0)] as CFDictionary }
        IOHIDManagerSetDeviceMatchingMultiple(manager, matching as CFArray)
        guard let set = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return [] }
        return set.compactMap { dev in
            let info = MacropedDeviceInfo(
                vendorID: UInt16(truncatingIfNeeded: intProp(dev, kIOHIDVendorIDKey)),
                productID: UInt16(truncatingIfNeeded: intProp(dev, kIOHIDProductIDKey)),
                product: cleanName(stringProp(dev, kIOHIDProductKey)) ?? "Mini Keyboard",
                manufacturer: stringProp(dev, kIOHIDManufacturerKey) ?? "",
                usagePage: intProp(dev, kIOHIDPrimaryUsagePageKey),
                usage: intProp(dev, kIOHIDPrimaryUsageKey),
                maxOutputReportSize: intProp(dev, kIOHIDMaxOutputReportSizeKey),
                maxInputReportSize: intProp(dev, kIOHIDMaxInputReportSizeKey),
                locationID: intProp(dev, kIOHIDLocationIDKey),
                registryID: registryID(dev)
            )
            guard MacropedProtocol.productIDs.contains(info.productID) else { return nil }
            return (dev, info)
        }
    }

    private static func intProp(_ dev: IOHIDDevice, _ key: String) -> Int {
        (IOHIDDeviceGetProperty(dev, key as CFString) as? NSNumber)?.intValue ?? 0
    }

    private static func stringProp(_ dev: IOHIDDevice, _ key: String) -> String? {
        IOHIDDeviceGetProperty(dev, key as CFString) as? String
    }

    /// These firmwares often append garbage to the USB product string (e.g. "USB Keyboardȉ").
    private static func cleanName(_ name: String?) -> String? {
        let ascii = String((name ?? "").unicodeScalars.filter { $0.isASCII && $0.value >= 0x20 && $0.value < 0x7F }.map(Character.init))
            .trimmingCharacters(in: .whitespaces)
        return ascii.isEmpty ? nil : ascii
    }

    private static func registryID(_ dev: IOHIDDevice) -> UInt64 {
        var id: UInt64 = 0
        IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(dev), &id)
        return id
    }

    // MARK: Lifecycle

    private init(device: IOHIDDevice, info: MacropedDeviceInfo) throws {
        self.device = device
        self.info = info
        inputBuffer = .allocate(capacity: inputBufferSize)
        thread = HIDRunLoopThread()

        let result = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            inputBuffer.deallocate()
            if result == kIOReturnNotPermitted { throw MacropedError.permissionDenied }
            throw MacropedError.openFailed(result)
        }
        isOpen = true

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(device, inputBuffer, inputBufferSize, { ctx, _, _, _, _, report, length in
            guard let ctx else { return }
            let me = Unmanaged<MacropedDevice>.fromOpaque(ctx).takeUnretainedValue()
            me.enqueue(Array(UnsafeBufferPointer(start: report, count: length)))
        }, context)
        thread.start { runLoop in
            IOHIDDeviceScheduleWithRunLoop(device, runLoop, CFRunLoopMode.defaultMode.rawValue)
        }
    }

    deinit {
        close()
        inputBuffer.deallocate()
    }

    public func close() {
        lock.lock()
        defer { lock.unlock() }
        guard isOpen else { return }
        isOpen = false
        if let rl = thread.runLoop {
            IOHIDDeviceUnscheduleFromRunLoop(device, rl, CFRunLoopMode.defaultMode.rawValue)
        }
        IOHIDDeviceRegisterInputReportCallback(device, inputBuffer, inputBufferSize, nil, nil)
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        thread.stop()
    }

    // MARK: I/O

    /// Called on the HID thread for every input report (debugging aid).
    public var onInputReport: (([UInt8]) -> Void)?

    private func enqueue(_ report: [UInt8]) {
        onInputReport?(report)
        lock.lock()
        queue.append(report)
        lock.unlock()
        available.signal()
    }

    private func drain() {
        lock.lock()
        queue.removeAll()
        lock.unlock()
        while available.wait(timeout: .now()) == .success {}
    }

    private func next(timeout: TimeInterval) -> [UInt8]? {
        guard available.wait(timeout: .now() + timeout) == .success else { return nil }
        lock.lock()
        defer { lock.unlock() }
        return queue.isEmpty ? nil : queue.removeFirst()
    }

    /// Sends one 65-byte output report (byte 0 = Report ID), like hidapi's `hid_write`.
    public func send(_ report: [UInt8]) throws {
        let result = report.withUnsafeBufferPointer { buf in
            IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, CFIndex(report[0]), buf.baseAddress!, buf.count)
        }
        guard result == kIOReturnSuccess else { throw MacropedError.writeFailed(result) }
    }

    /// Asks the firmware for its key/knob count. Returns nil if it does not answer.
    public func identify(timeout: TimeInterval = 0.5) -> PadLayout? {
        drain()
        guard (try? send(MacropedProtocol.identifyReport)) != nil else { return nil }
        let deadline = Date().addingTimeInterval(timeout)
        while case let remaining = deadline.timeIntervalSinceNow, remaining > 0, let r = next(timeout: remaining) {
            if let layout = MacropedProtocol.decodeIdentify(r) { return layout }
        }
        return nil
    }

    /// Reads back the configuration of every layer the firmware reports.
    public func readProfile(layout: PadLayout, timeout: TimeInterval = 0.4) throws -> (DeviceProfile, rawReports: Int) {
        var profile = DeviceProfile(name: "Lido do dispositivo", layout: layout)
        var count = 0
        for layer in 0..<DeviceProfile.layerCount {
            drain()
            try send(MacropedProtocol.readLayerReport(layer: layer))
            while let r = next(timeout: timeout) {
                count += 1
                switch MacropedProtocol.decode(r) {
                case .binding(let l, let slot, let action)?:
                    // The firmware reports all 15 keys / 3 knobs; keep only what physically exists.
                    if layout.slots.contains(slot) { profile.layers[l][slot] = action }
                case .led(let l, let config)?:
                    profile.layers[l].led = config
                case nil:
                    continue
                }
            }
        }
        return (profile, count)
    }

    /// Programs the whole profile into the device's flash.
    public func write(_ profile: DeviceProfile, progress: ((Double) -> Void)? = nil) throws {
        let layers = MacropedProtocol.reports(for: profile)
        let total = Double(layers.reduce(0) { $0 + $1.count })
        var done = 0.0
        for (index, reports) in layers.enumerated() {
            for r in reports {
                try send(r)
                done += 1
                progress?(done / total)
                Thread.sleep(forTimeInterval: 0.01)
            }
            if index < layers.count - 1 { Thread.sleep(forTimeInterval: commitDelay) }
        }
    }
}

/// Dedicated thread whose run loop delivers HID input reports.
final class HIDRunLoopThread: Thread, @unchecked Sendable {
    private(set) var runLoop: CFRunLoop?
    private var setup: ((CFRunLoop) -> Void)?
    private let ready = DispatchSemaphore(value: 0)

    func start(setup: @escaping (CFRunLoop) -> Void) {
        self.setup = setup
        name = "Amael Macroped HID"
        start()
        ready.wait()
    }

    override func main() {
        let rl = CFRunLoopGetCurrent()!
        runLoop = rl
        var ctx = CFRunLoopSourceContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil,
                                         equal: nil, hash: nil, schedule: nil, cancel: nil, perform: { _ in })
        let keepAlive = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &ctx)
        CFRunLoopAddSource(rl, keepAlive, .defaultMode)
        setup?(rl)
        setup = nil
        ready.signal()
        CFRunLoopRun()
    }

    func stop() {
        if let rl = runLoop { CFRunLoopStop(rl) }
    }
}
