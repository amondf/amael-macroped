import MacropedKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()
            Divider()
            HStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        LayerBar()
                        PadView()
                        LEDSection()
                    }
                    .padding(20)
                }
                .frame(minWidth: 400, idealWidth: 440)
                Divider()
                Group {
                    if let slot = model.selectedSlot {
                        SlotEditor(slot: slot)
                    } else {
                        Text("Selecione uma tecla ou direção do knob").foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(minWidth: 400, maxWidth: .infinity)
            }
            Divider()
            FooterView()
        }
        .alert("Amael Macroped", isPresented: Binding(get: { model.alert != nil }, set: { if !$0 { model.alert = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.alert ?? "")
        }
    }
}

// MARK: Header / footer

private struct HeaderView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "keyboard.badge.ellipsis")
                .font(.system(size: 26))
                .foregroundStyle(Color.accentOrange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Amael Macroped").font(.title2.bold())
                Text("Configurador nativo Apple Silicon para mini teclados CH57x")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            ConnectionBadge()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

private struct ConnectionBadge: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(model.isConnected ? Color.green : Color.red).frame(width: 9, height: 9)
            switch model.connection {
            case .disconnected:
                Text("Desconectado").font(.callout)
            case .connected(let info, let layout):
                VStack(alignment: .trailing, spacing: 0) {
                    Text(info.product).font(.callout.weight(.medium))
                    Text(String(format: "%04X:%04X", info.vendorID, info.productID)
                         + (layout.map { " · \($0.keys) teclas · \($0.knobs) knob" } ?? ""))
                        .font(.caption2.monospaced()).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.6), in: Capsule())
    }
}

private struct FooterView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 12) {
            if model.busy {
                ProgressView(value: model.progress).frame(width: 120)
            }
            Text(model.status).font(.callout).foregroundStyle(.secondary).lineLimit(2)
            Spacer()
            Button("Ler do teclado") { model.readFromDevice() }
                .disabled(!model.isConnected || model.busy)
            Button {
                model.writeToDevice()
            } label: {
                Label(model.hasUnsavedChanges ? "Gravar no teclado •" : "Gravar no teclado", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentOrange)
            .disabled(!model.isConnected || model.busy)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: Layers

private struct LayerBar: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack {
            Picker("Camada", selection: $model.layer) {
                ForEach(0..<DeviceProfile.layerCount, id: \.self) { Text("Camada \($0 + 1)").tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Menu {
                ForEach(0..<DeviceProfile.layerCount, id: \.self) { target in
                    if target != model.layer {
                        Button("Copiar para camada \(target + 1)") { model.copyLayer(to: target) }
                    }
                }
                Divider()
                Button("Limpar esta camada", role: .destructive) { model.clearLayer() }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }
}

// MARK: LED

private struct LEDSection: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Configurar iluminação nesta camada", isOn: Binding(
                    get: { model.led != nil },
                    set: { model.led = $0 ? LEDConfig(mode: 1, color: .orange) : nil }
                ))
                if let led = model.led {
                    Picker("Efeito", selection: Binding(
                        get: { led.mode },
                        set: { model.led = LEDConfig(mode: $0, color: led.color) }
                    )) {
                        Text("Desligado").tag(UInt8(0))
                        ForEach(1...5, id: \.self) { Text("Efeito \($0)").tag(UInt8($0)) }
                    }
                    .frame(maxWidth: 260)
                    HStack(spacing: 8) {
                        Text("Cor")
                        ForEach(LEDColor.allCases, id: \.self) { color in
                            Button {
                                model.led = LEDConfig(mode: led.mode, color: color)
                            } label: {
                                Circle().fill(color.swatch).frame(width: 20, height: 20)
                                    .overlay(Circle().stroke(Color.primary, lineWidth: led.color == color ? 2 : 0).padding(-3))
                            }
                            .buttonStyle(.plain)
                            .help(color.displayName)
                        }
                    }
                    Text("Os efeitos são definidos pelo firmware; alguns modelos ignoram a cor em certos efeitos.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("Iluminação", systemImage: "lightbulb")
        }
    }
}

extension LEDColor {
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

extension Color {
    static let accentOrange = Color(red: 1.0, green: 0.55, blue: 0.15)
}
