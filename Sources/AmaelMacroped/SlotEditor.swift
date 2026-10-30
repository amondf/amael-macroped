import AppKit
import MacropedKit
import SwiftUI

struct SlotEditor: View {
    @EnvironmentObject private var model: AppModel
    let slot: Slot

    private enum Kind: String, CaseIterable, Identifiable {
        case none = "Nenhuma", keys = "Teclas", media = "Multimídia", mouse = "Mouse"
        var id: String { rawValue }
    }

    private var action: KeyAction { model.action(for: slot) }

    private var kind: Binding<Kind> {
        Binding {
            switch action {
            case .none: return .none
            case .keys: return .keys
            case .media: return .media
            case .mouse: return .mouse
            }
        } set: { newKind in
            switch newKind {
            case .none: model.setAction(.none, for: slot)
            case .keys: model.setAction(.keys([]), for: slot)
            case .media: model.setAction(.media(.playPause), for: slot)
            case .mouse: model.setAction(.mouse(.leftClick), for: slot)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(slot.displayName).font(.title3.bold())
                Text("Camada \(model.layer + 1)").font(.caption).foregroundStyle(.secondary)
            }
            Picker("Ação", selection: kind) {
                ForEach(Kind.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            switch action {
            case .none:
                Text("Esta entrada não envia nada.").foregroundStyle(.secondary)
                Spacer()
            case .keys(let chords):
                KeysEditor(chords: chords) { model.setAction(.keys($0), for: slot) }
            case .media(let current):
                OptionGrid(items: MediaKey.allCases, selected: current, title: \.displayName) {
                    model.setAction(.media($0), for: slot)
                }
            case .mouse(let current):
                OptionGrid(items: MouseAction.allCases, selected: current, title: \.displayName) {
                    model.setAction(.mouse($0), for: slot)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .id(slot)
    }
}

private struct OptionGrid<Item: Hashable>: View {
    let items: [Item]
    let selected: Item
    let title: KeyPath<Item, String>
    let pick: (Item) -> Void

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Button {
                        pick(item)
                    } label: {
                        Text(item[keyPath: title])
                            .frame(maxWidth: .infinity, minHeight: 30)
                            .padding(.horizontal, 6)
                            .background(RoundedRectangle(cornerRadius: 7)
                                .fill(item == selected ? Color.accentOrange.opacity(0.85) : Color.secondary.opacity(0.12)))
                            .foregroundStyle(item == selected ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: Keyboard macro editor

private struct KeysEditor: View {
    let chords: [KeyChord]
    let update: ([KeyChord]) -> Void

    @State private var recording = false
    @State private var monitor: Any?
    @State private var text = ""
    @State private var textError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    recording ? stopRecording() : startRecording()
                } label: {
                    Label(recording ? "Pressione o atalho… (Esc cancela)" : "Gravar atalho",
                          systemImage: recording ? "record.circle.fill" : "record.circle")
                }
                .tint(recording ? .red : nil)
                Button {
                    update(chords + [KeyChord(keyCode: HIDKeys.a)])
                } label: {
                    Label("Adicionar tecla", systemImage: "plus")
                }
                .disabled(chords.count >= MacropedProtocol.maxChords)
                Spacer()
                Text("\(chords.count)/\(MacropedProtocol.maxChords)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }

            if chords.isEmpty {
                Text("Nenhuma tecla. Use “Gravar atalho” (ex.: ⌘⇧4) ou adicione teclas manualmente. "
                     + "Várias teclas formam uma macro executada em sequência.")
                    .font(.callout).foregroundStyle(.secondary)
            }

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(Array(chords.enumerated()), id: \.offset) { index, chord in
                        ChordRow(index: index, chord: chord) { new in
                            var c = chords
                            if let new { c[index] = new } else { c.remove(at: index) }
                            update(c)
                        }
                    }
                }
            }

            GroupBox("Digitar texto (layout US)") {
                HStack {
                    TextField("ex.: git status", text: $text)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(convertText)
                    Button("Converter em macro", action: convertText).disabled(text.isEmpty)
                }
                .padding(4)
                if let textError {
                    Text(textError).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .onDisappear(perform: stopRecording)
    }

    private func convertText() {
        guard let converted = HIDKeys.chords(forText: text) else {
            textError = "Somente caracteres ASCII são suportados (sem acentos)."
            return
        }
        textError = nil
        update(Array((chords + converted).prefix(MacropedProtocol.maxChords)))
        text = ""
    }

    private func startRecording() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            defer { stopRecording() }
            if event.keyCode == 0x35 && event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
                return nil
            }
            if let code = HIDKeys.fromMacKeyCode[event.keyCode], chords.count < MacropedProtocol.maxChords {
                update(chords + [KeyChord(modifiers: Modifiers(event.modifierFlags), keyCode: code)])
            }
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
    }
}

private struct ChordRow: View {
    let index: Int
    let chord: KeyChord
    let change: (KeyChord?) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("\(index + 1)").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 18)
            modifier("⌃", .control, help: "Control")
            modifier("⌥", .option, help: "Option")
            modifier("⇧", .shift, help: "Shift")
            modifier("⌘", .command, help: "Command")
            Picker("", selection: Binding(get: { chord.keyCode }, set: {
                change(KeyChord(modifiers: chord.modifiers, keyCode: $0))
            })) {
                Text("(somente modificadores)").tag(UInt8(0))
                ForEach(HIDKeys.groups, id: \.self) { group in
                    Section(group) {
                        ForEach(HIDKeys.all.filter { $0.group == group }) { Text($0.name).tag($0.code) }
                    }
                }
            }
            .labelsHidden()
            .frame(minWidth: 150)
            Button {
                change(nil)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Remover")
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
    }

    private func modifier(_ symbol: String, _ mod: Modifiers, help: String) -> some View {
        let on = chord.modifiers.contains(mod)
        return Button {
            var m = chord.modifiers
            if on { m.remove(mod) } else { m.insert(mod) }
            change(KeyChord(modifiers: m, keyCode: chord.keyCode))
        } label: {
            Text(symbol)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 26, height: 24)
                .background(RoundedRectangle(cornerRadius: 5).fill(on ? Color.accentOrange : Color.secondary.opacity(0.15)))
                .foregroundStyle(on ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

extension Modifiers {
    init(_ flags: NSEvent.ModifierFlags) {
        var m: Modifiers = []
        if flags.contains(.control) { m.insert(.control) }
        if flags.contains(.option) { m.insert(.option) }
        if flags.contains(.shift) { m.insert(.shift) }
        if flags.contains(.command) { m.insert(.command) }
        self = m
    }
}
