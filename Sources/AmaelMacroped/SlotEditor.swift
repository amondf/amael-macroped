import AppKit
import MacropedKit
import SwiftUI

struct SlotEditor: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: Localizer
    let slot: Slot

    private enum Kind: CaseIterable { case none, keys, media, mouse }

    private func title(_ kind: Kind) -> String {
        switch kind {
        case .none: return loc.s.kindNone
        case .keys: return loc.s.kindKeys
        case .media: return loc.s.kindMedia
        case .mouse: return loc.s.kindMouse
        }
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
        VStack(alignment: .leading, spacing: AppStyle.Spacing.small) {
            VStack(alignment: .leading, spacing: AppStyle.Spacing.xxxSmall) {
                Text(loc.s.slotName(slot)).font(AppStyle.Typography.sectionTitle).foregroundStyle(AppColors.textPrimary)
                Text(loc.s.layer(model.layer + 1)).font(AppStyle.Typography.metadata).foregroundStyle(AppColors.textSecondary)
            }
            SegmentedControl(options: Kind.allCases, selection: kind, title: title)

            switch action {
            case .none:
                Card { Text(loc.s.noAction).font(AppStyle.Typography.body).foregroundStyle(AppColors.textSecondary) }
                Spacer()
            case .keys(let chords):
                KeysEditor(chords: chords) { model.setAction(.keys($0), for: slot) }
            case .media(let current):
                OptionGrid(items: MediaKey.allCases, selected: current, title: loc.s.mediaName) {
                    model.setAction(.media($0), for: slot)
                }
            case .mouse(let current):
                OptionGrid(items: MouseAction.allCases, selected: current, title: loc.s.mouseName) {
                    model.setAction(.mouse($0), for: slot)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .id(slot)
    }
}

private struct OptionGrid<Item: Hashable>: View {
    let items: [Item]
    let selected: Item
    let title: (Item) -> String
    let pick: (Item) -> Void

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: AppStyle.Spacing.xSmall)],
                      spacing: AppStyle.Spacing.xSmall) {
                ForEach(items, id: \.self) { item in
                    OptionTile(text: title(item), selected: item == selected) { pick(item) }
                }
            }
        }
        .scrollIndicators(.never)
    }
}

private struct OptionTile: View {
    let text: String
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(selected ? AppStyle.Typography.headline : AppStyle.Typography.body)
                .foregroundStyle(selected ? AppColors.onActionPrimary : AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 32)
                .padding(.horizontal, AppStyle.Spacing.xSmall)
                .background(selected ? AppColors.actionPrimary : (hovering ? AppColors.surfaceCardHover : AppColors.surfaceCard),
                            in: RoundedRectangle(cornerRadius: AppStyle.Radius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: AppStyle.Radius.md, style: .continuous)
                    .strokeBorder(selected ? .clear : AppColors.borderSubtle, lineWidth: 0.5))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: Keyboard macro editor

private struct KeysEditor: View {
    @EnvironmentObject private var loc: Localizer
    let chords: [KeyChord]
    let update: ([KeyChord]) -> Void

    @State private var recording = false
    @State private var monitor: Any?
    @State private var text = ""
    @State private var textError = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppStyle.Spacing.small) {
            HStack(spacing: AppStyle.Spacing.xSmall) {
                Button {
                    recording ? stopRecording() : startRecording()
                } label: {
                    Label(recording ? loc.s.recordingPrompt : loc.s.recordShortcut,
                          systemImage: recording ? "record.circle.fill" : "record.circle")
                }
                .buttonStyle(.app(recording ? .primary : .secondary))
                Button {
                    update(chords + [KeyChord(keyCode: HIDKeys.a)])
                } label: {
                    Label(loc.s.addKey, systemImage: "plus")
                }
                .buttonStyle(.app(.quiet))
                .disabled(chords.count >= MacropedProtocol.maxChords)
                Spacer()
                Text("\(chords.count)/\(MacropedProtocol.maxChords)")
                    .font(AppStyle.Typography.metadata.numbers)
                    .monospacedDigit()
                    .foregroundStyle(AppColors.textTertiary)
            }

            if chords.isEmpty {
                Card {
                    Text(loc.s.emptyKeysHint).font(AppStyle.Typography.callout).foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                ScrollView {
                    Card(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(chords.enumerated()), id: \.offset) { index, chord in
                                if index > 0 { CardDivider() }
                                ChordRow(index: index, chord: chord) { new in
                                    var c = chords
                                    if let new { c[index] = new } else { c.remove(at: index) }
                                    update(c)
                                }
                            }
                        }
                    }
                }
                .scrollIndicators(.never)
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: AppStyle.Spacing.xxSmallPlus) {
                Text(loc.s.typeTextTitle).font(AppStyle.Typography.headline).foregroundStyle(AppColors.textPrimary)
                HStack(spacing: AppStyle.Spacing.xSmall) {
                    TextField(loc.s.typeTextPlaceholder, text: $text)
                        .modifier(FieldBackground())
                        .onSubmit(convertText)
                    Button(loc.s.convertToMacro, action: convertText)
                        .buttonStyle(.app(.secondary))
                        .disabled(text.isEmpty)
                }
                if textError {
                    Text(loc.s.asciiOnly).font(AppStyle.Typography.callout).foregroundStyle(AppColors.statusDangerText)
                }
            }
        }
        .onDisappear(perform: stopRecording)
    }

    private func convertText() {
        guard let converted = HIDKeys.chords(forText: text) else {
            textError = true
            return
        }
        textError = false
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
    @EnvironmentObject private var loc: Localizer
    let index: Int
    let chord: KeyChord
    let change: (KeyChord?) -> Void

    var body: some View {
        HStack(spacing: AppStyle.Spacing.xSmall) {
            Text("\(index + 1)")
                .font(AppStyle.Typography.metadata.numbers)
                .monospacedDigit()
                .foregroundStyle(AppColors.textTertiary)
                .frame(width: 18)
            HStack(spacing: AppStyle.Spacing.xxSmall) {
                modifier("⌃", .control, help: "Control")
                modifier("⌥", .option, help: "Option")
                modifier("⇧", .shift, help: "Shift")
                modifier("⌘", .command, help: "Command")
            }
            Dropdown(value: chord.keyCode == 0 ? loc.s.modifiersOnly : loc.s.keyName(chord.keyCode), minWidth: 150) {
                Button(loc.s.modifiersOnly) { set(0) }
                ForEach(HIDKeys.groups, id: \.self) { group in
                    Menu(loc.s.keyGroup(group)) {
                        ForEach(HIDKeys.all.filter { $0.group == group }) { entry in
                            Button(loc.s.keyName(entry.code)) { set(entry.code) }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            Button {
                change(nil)
            } label: {
                Label(loc.s.remove, systemImage: "trash").labelStyle(.iconOnly)
            }
            .buttonStyle(.app(.quiet, size: .small, width: .square))
            .help(loc.s.remove)
        }
        .padding(.horizontal, AppStyle.Spacing.small)
        .padding(.vertical, AppStyle.Spacing.xSmall)
    }

    private func set(_ code: UInt8) {
        change(KeyChord(modifiers: chord.modifiers, keyCode: code))
    }

    private func modifier(_ symbol: String, _ mod: Modifiers, help: String) -> some View {
        let on = chord.modifiers.contains(mod)
        return Button {
            var m = chord.modifiers
            if on { m.remove(mod) } else { m.insert(mod) }
            change(KeyChord(modifiers: m, keyCode: chord.keyCode))
        } label: {
            Text(symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 26, height: 26)
                .background(on ? AppColors.actionPrimary : AppColors.fillSecondary,
                            in: RoundedRectangle(cornerRadius: AppStyle.Radius.sm, style: .continuous))
                .foregroundStyle(on ? AppColors.onActionPrimary : AppColors.textSecondary)
                .contentShape(Rectangle())
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
