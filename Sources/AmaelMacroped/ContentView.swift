import AppKit
import MacropedKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: Localizer

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()
            HStack(alignment: .top, spacing: AppStyle.Spacing.large) {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppStyle.Spacing.small) {
                        SectionHeader(title: loc.s.layers) { LayerMenu() }
                        SegmentedControl(options: Array(0..<DeviceProfile.layerCount), selection: $model.layer) {
                            loc.s.layer($0 + 1)
                        }
                        PadView()
                        SectionHeader(loc.s.lighting).padding(.top, AppStyle.Spacing.small)
                        LEDSection()
                    }
                    .padding(.bottom, AppStyle.Spacing.medium)
                }
                .scrollIndicators(.never)
                .frame(width: 448)

                Group {
                    if let slot = model.selectedSlot {
                        SlotEditor(slot: slot)
                    } else {
                        Card {
                            Text(loc.s.selectSlotHint).font(AppStyle.Typography.body).foregroundStyle(AppColors.textSecondary)
                        }
                    }
                }
                .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(.horizontal, AppStyle.Spacing.large)
            Rectangle().fill(AppColors.borderSubtle).frame(height: 0.5)
            FooterView()
        }
        .background(AppColors.surfaceBase)
        .tint(AppColors.actionPrimary)
        .alert("Amael Macroped", isPresented: Binding(get: { model.alert != nil }, set: { if !$0 { model.alert = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.alert.map(loc.s.status) ?? "")
        }
    }
}

// MARK: Header / footer

private struct HeaderView: View {
    @EnvironmentObject private var loc: Localizer

    var body: some View {
        HStack(spacing: AppStyle.Spacing.small) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: AppStyle.Spacing.xxxSmall) {
                Text("Amael Macroped").font(AppStyle.Typography.pageTitle).foregroundStyle(AppColors.textPrimary)
                Text(loc.s.appSubtitle).font(AppStyle.Typography.callout).foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
            if let url = Support.donationURL {
                Link(destination: url) {
                    Label {
                        Text("Buy me a coffee")
                    } icon: {
                        Image(systemName: "cup.and.saucer.fill").foregroundStyle(AppColors.accentCelebrate)
                    }
                }
                .buttonStyle(.app(.secondary))
                .help(loc.s.donateHelp)
            }
            ConnectionTag()
            SettingsButton()
        }
        .padding(.horizontal, AppStyle.Spacing.large)
        .padding(.vertical, AppStyle.Spacing.medium)
    }
}

private struct SettingsButton: View {
    @EnvironmentObject private var loc: Localizer

    var body: some View {
        Group {
            if #available(macOS 14, *) {
                SettingsLink { Label(loc.s.settings, systemImage: "gearshape").labelStyle(.iconOnly) }
            } else {
                Button {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } label: {
                    Label(loc.s.settings, systemImage: "gearshape").labelStyle(.iconOnly)
                }
            }
        }
        .buttonStyle(.app(.quiet, width: .square))
        .help(loc.s.settings)
    }
}

private struct ConnectionTag: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: Localizer

    var body: some View {
        switch model.connection {
        case .disconnected:
            StatusTag(kind: .unsure, text: loc.s.disconnected)
        case .connected(let info, let layout):
            StatusTag(kind: .safe, text: info.product + (layout.map { loc.s.keysKnobs($0.keys, $0.knobs) } ?? ""))
                .help(String(format: "VID %04X · PID %04X", info.vendorID, info.productID))
        }
    }
}

private struct FooterView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: Localizer
    @State private var confirmClear = false

    var body: some View {
        HStack(spacing: AppStyle.Spacing.xSmall) {
            if model.busy {
                ProgressView(value: model.progress).frame(width: 100)
            }
            Text(loc.s.status(model.status))
                .font(AppStyle.Typography.callout)
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(2)
            Spacer(minLength: AppStyle.Spacing.small)
            Button {
                confirmClear = true
            } label: {
                Label(loc.s.clearAll, systemImage: "trash")
            }
            .buttonStyle(.app(.quiet))
            .disabled(model.busy)
            .confirmationDialog(loc.s.clearAllTitle, isPresented: $confirmClear) {
                Button(loc.s.clearAll, role: .destructive) { model.clearAll() }
                Button(loc.s.cancel, role: .cancel) {}
            } message: {
                Text(loc.s.clearAllMessage)
            }
            Button(loc.s.readFromDevice) { model.readFromDevice() }
                .buttonStyle(.app(.secondary))
                .disabled(!model.isConnected || model.busy)
            Button {
                model.writeToDevice()
            } label: {
                Label(loc.s.writeToDevice + (model.hasUnsavedChanges ? " •" : ""), systemImage: "arrow.down.to.line")
            }
            .buttonStyle(.app(.primary))
            .disabled(!model.isConnected || model.busy)
        }
        .padding(.horizontal, AppStyle.Spacing.large)
        .padding(.vertical, AppStyle.Spacing.small)
        .background(AppColors.surfaceBase)
    }
}

// MARK: Layers

private struct LayerMenu: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: Localizer

    var body: some View {
        Menu {
            ForEach(0..<DeviceProfile.layerCount, id: \.self) { target in
                if target != model.layer {
                    Button(loc.s.copyToLayer(target + 1)) { model.copyLayer(to: target) }
                }
            }
            Divider()
            Button(loc.s.clearLayer, role: .destructive) { model.clearLayer() }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.textTertiary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

// MARK: LED

private struct LEDSection: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: Localizer

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: AppStyle.Spacing.small) {
                CardRow(title: loc.s.configureLighting, caption: loc.s.lightingNote) {
                    Toggle("", isOn: Binding(
                        get: { model.led != nil },
                        set: { model.led = $0 ? LEDConfig(mode: 1, color: .orange) : nil }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(AppColors.actionPrimary)
                }
                if let led = model.led {
                    CardDivider()
                    CardRow(title: loc.s.effect) {
                        Dropdown(value: led.mode == 0 ? loc.s.effectOff : loc.s.effectN(Int(led.mode)), minWidth: 130) {
                            Button(loc.s.effectOff) { model.led = LEDConfig(mode: 0, color: led.color) }
                            ForEach(1...5, id: \.self) { n in
                                Button(loc.s.effectN(n)) { model.led = LEDConfig(mode: UInt8(n), color: led.color) }
                            }
                        }
                    }
                    CardDivider()
                    CardRow(title: loc.s.color) {
                        HStack(spacing: AppStyle.Spacing.xSmall) {
                            ForEach(LEDColor.allCases, id: \.self) { color in
                                Button {
                                    model.led = LEDConfig(mode: led.mode, color: color)
                                } label: {
                                    Circle().fill(color.swatch).frame(width: 16, height: 16)
                                        .padding(AppStyle.Spacing.xxxSmall)
                                        .overlay(Circle().strokeBorder(AppColors.actionPrimary,
                                                                       lineWidth: led.color == color ? 1.5 : 0))
                                }
                                .buttonStyle(.plain)
                                .help(loc.s.colorName(color))
                            }
                        }
                    }
                }
            }
        }
    }
}

extension LEDColor {
    /// The physical LED colour (not a theme colour: it shows what the keyboard will light).
    var swatch: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .cyan: return .cyan
        case .blue: return .blue
        case .purple: return .purple
        }
    }
}
