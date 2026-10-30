import MacropedKit
import SwiftUI

/// Visual replica of the pad: keys in a row (wrapping every 5) plus knobs on the right.
struct PadView: View {
    @EnvironmentObject private var model: AppModel

    private var keyRows: [[Int]] {
        let keys = Array(1...model.layout.keys)
        return stride(from: 0, to: keys.count, by: 5).map { Array(keys[$0..<min($0 + 5, keys.count)]) }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(spacing: 12) {
                ForEach(keyRows, id: \.self) { row in
                    HStack(spacing: 12) {
                        ForEach(row, id: \.self) { n in KeyCap(slot: .key(n), title: "K\(n)") }
                    }
                }
            }
            if model.layout.knobs > 0 {
                VStack(spacing: 14) {
                    ForEach(0..<model.layout.knobs, id: \.self) { KnobView(index: $0) }
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(colors: [Color.accentOrange.opacity(0.22), Color.accentOrange.opacity(0.06)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.accentOrange.opacity(0.45), lineWidth: 1))
        )
    }
}

private struct KeyCap: View {
    @EnvironmentObject private var model: AppModel
    let slot: Slot
    let title: String

    var body: some View {
        let selected = model.selectedSlot == slot
        Button {
            model.selectedSlot = slot
        } label: {
            VStack(spacing: 6) {
                Text(title).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Text(model.action(for: slot).summary)
                    .font(.system(size: 12, weight: .medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
            }
            .padding(6)
            .frame(width: 78, height: 78)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 2)
            )
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color.accentOrange : .clear, lineWidth: 2.5))
        }
        .buttonStyle(.plain)
        .help(slot.displayName)
    }
}

private struct KnobView: View {
    @EnvironmentObject private var model: AppModel
    let index: Int

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                part(.knobLeft(index), icon: "arrow.counterclockwise")
                Button {
                    model.selectedSlot = .knobPress(index)
                } label: {
                    ZStack {
                        Circle().fill(LinearGradient(colors: [.gray.opacity(0.9), .black], startPoint: .top, endPoint: .bottom))
                        Circle().stroke(Color.white.opacity(0.5), lineWidth: 1).padding(4)
                        Image(systemName: "circle.fill").font(.system(size: 9)).foregroundStyle(.white.opacity(0.8))
                    }
                    .frame(width: 58, height: 58)
                    .overlay(Circle().stroke(model.selectedSlot == .knobPress(index) ? Color.accentOrange : .clear, lineWidth: 2.5).padding(-3))
                }
                .buttonStyle(.plain)
                .help(Slot.knobPress(index).displayName)
                part(.knobRight(index), icon: "arrow.clockwise")
            }
            Text("Knob \(index + 1)").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
        }
    }

    private func part(_ slot: Slot, icon: String) -> some View {
        Button {
            model.selectedSlot = slot
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color(nsColor: .windowBackgroundColor)))
                .overlay(Circle().stroke(model.selectedSlot == slot ? Color.accentOrange : Color.secondary.opacity(0.3),
                                         lineWidth: model.selectedSlot == slot ? 2.5 : 1))
        }
        .buttonStyle(.plain)
        .help(slot.displayName + " — " + model.action(for: slot).summary)
    }
}
