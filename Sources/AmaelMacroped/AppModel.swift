import AppKit
import Foundation
import MacropedKit
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    enum Connection: Equatable {
        case disconnected
        case connected(MacropedDeviceInfo, PadLayout?)
    }

    @Published var profile: DeviceProfile { didSet { persist() } }
    @Published var layer = 0
    @Published var selectedSlot: Slot? = .key(1)
    @Published private(set) var connection: Connection = .disconnected
    @Published private(set) var busy = false
    @Published private(set) var progress: Double = 0
    @Published var status: StatusMessage = .searching
    @Published var alert: StatusMessage?
    @Published var hasUnsavedChanges = false

    private var timer: Timer?
    private let worker = DispatchQueue(label: "amael.macroped.device")

    private static var storeURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Amael Macroped", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("profile.json")
    }

    init() {
        if let data = try? Data(contentsOf: Self.storeURL),
           let saved = try? JSONDecoder().decode(DeviceProfile.self, from: data) {
            profile = saved
        } else {
            profile = .defaultProfile()
            hasUnsavedChanges = true
        }
        refreshDevice()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshDevice() }
        }
    }

    // MARK: Editing

    var layout: PadLayout { profile.layout }

    func action(for slot: Slot) -> KeyAction { profile.layers[layer][slot] }

    func setAction(_ action: KeyAction, for slot: Slot) {
        profile.layers[layer][slot] = action
        hasUnsavedChanges = true
    }

    var led: LEDConfig? {
        get { profile.layers[layer].led }
        set {
            profile.layers[layer].led = newValue
            hasUnsavedChanges = true
        }
    }

    func clearLayer() {
        profile.layers[layer] = LayerConfig(led: profile.layers[layer].led)
        hasUnsavedChanges = true
    }

    func copyLayer(to target: Int) {
        profile.layers[target] = profile.layers[layer]
        hasUnsavedChanges = true
        status = .layerCopied(layer + 1, target + 1)
    }

    /// Removes every action from all layers (lighting is kept) and writes it to the keyboard when connected.
    func clearAll() {
        for i in profile.layers.indices { profile.layers[i].bindings = [] }
        hasUnsavedChanges = true
        if isConnected {
            writeToDevice()
        } else {
            status = .clearedAll
        }
    }

    func resetToDefault() {
        profile = .defaultProfile(layout: layout)
        hasUnsavedChanges = true
    }

    func setLayout(_ layout: PadLayout) {
        profile.layout = layout
        if let s = selectedSlot, !layout.slots.contains(s) { selectedSlot = layout.slots.first }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(profile) { try? data.write(to: Self.storeURL) }
    }

    // MARK: Device

    var isConnected: Bool {
        if case .connected = connection { return true }
        return false
    }

    func refreshDevice() {
        guard !busy else { return }
        let list = MacropedDevice.list()
        guard let info = list.first else {
            if isConnected || status == .searching {
                connection = .disconnected
                status = .disconnectedHint
            }
            return
        }
        if case .connected(let current, _) = connection, current.registryID == info.registryID { return }
        connection = .connected(info, nil)
        status = .connected(info.product)
        identify()
    }

    private func identify() {
        run(.identifying) { dev in
            dev.identify()
        } done: { [weak self] layout in
            guard let self, case .connected(let info, _) = self.connection else { return }
            self.connection = .connected(info, layout)
            if let layout, layout != self.profile.layout { self.setLayout(layout) }
            self.status = layout.map { .connectedLayout(info.product, $0.keys, $0.knobs) } ?? .connected(info.product)
        }
    }

    func writeToDevice() {
        let profile = self.profile
        run(.writing) { [weak self] dev in
            try dev.write(profile) { p in
                Task { @MainActor in self?.progress = p }
            }
        } done: { [weak self] _ in
            self?.hasUnsavedChanges = false
            self?.status = .writeSuccess
        }
    }

    func readFromDevice() {
        let layout = self.layout
        run(.reading) { dev in
            try dev.readProfile(layout: layout)
        } done: { [weak self] result in
            guard let self else { return }
            let (read, count) = result
            if count == 0 {
                self.status = .readUnsupported
                return
            }
            var merged = read
            merged.name = self.profile.name
            // The firmware does not report LED settings; keep the ones from the current profile.
            for i in merged.layers.indices where merged.layers[i].led == nil {
                merged.layers[i].led = self.profile.layers[i].led
            }
            self.profile = merged
            self.hasUnsavedChanges = false
            self.status = .readDone(count)
        }
    }

    private func run<T>(_ message: StatusMessage, _ work: @escaping @Sendable (MacropedDevice) throws -> T,
                        done: @escaping @MainActor (T) -> Void) {
        guard !busy else { return }
        busy = true
        progress = 0
        status = message
        worker.async { [weak self] in
            let result: Result<T, Error> = Result {
                let dev = try MacropedDevice.open()
                defer { dev.close() }
                return try work(dev)
            }
            let box = UncheckedBox(result)
            Task { @MainActor in
                guard let self else { return }
                self.busy = false
                switch box.value {
                case .success(let value):
                    done(value)
                case .failure(let error):
                    self.status = StatusMessage(error)
                    self.alert = StatusMessage(error)
                    if (error as? MacropedError) == .notFound { self.connection = .disconnected }
                }
            }
        }
    }

    // MARK: Files

    func saveProfileAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(profile.name).json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            try enc.encode(profile).write(to: url)
            status = .profileSaved(url.lastPathComponent)
        } catch {
            alert = .saveFailed(error.localizedDescription)
        }
    }

    func openProfile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            var p = try JSONDecoder().decode(DeviceProfile.self, from: Data(contentsOf: url))
            if case .connected(_, let layout?) = connection { p.layout = layout }
            profile = p
            hasUnsavedChanges = true
            status = .profileLoaded(p.name)
        } catch {
            alert = .invalidProfile(error.localizedDescription)
        }
    }
}

/// Moves a value produced on the worker queue back to the main actor.
private struct UncheckedBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}
