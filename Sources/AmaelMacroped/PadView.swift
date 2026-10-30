import MacropedKit
import SwiftUI

/// Visual replica of the pad: keys in rows of five plus knobs on the right.
struct PadView: View {
    @EnvironmentObject private var model: AppModel

    private var keyRows: [[Int]] {
        let keys = Array(1...model.layout.keys)
        return stride(from: 0, to: keys.count, by: 5).map { Array(keys[$0..<min($0 + 5, keys.count)]) }
    }

    var body: some View {
        Card(padding: AppStyle.Spacing.large) {
            HStack(alignment: .center, spacing: AppStyle.Spacing.large) {
                VStack(spacing: AppStyle.Spacing.small) {
                    ForEach(keyRows, id: \.self) { row in
                        HStack(spacing: AppStyle.Spacing.small) {
                            ForEach(row, id: \.self) { KeyCap(slot: .key($0), title: "K\($0)") }
                        }
                    }
                }
                if model.layout.knobs > 0 {
                    VStack(spacing: AppStyle.Spacing.medium) {
                        ForEach(0..<model.layout.knobs, id: \.self) { KnobView(index: $0) }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct KeyCap: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: Localizer
    @State private var hovering = false
    let slot: Slot
    let title: String

    var body: some View {
        let selected = model.selectedSlot == slot
        Button {
            model.selectedSlot = slot
        } label: {
            VStack(spacing: AppStyle.Spacing.xxSmall) {
                Text(title).font(AppStyle.Typography.micro).foregroundStyle(AppColors.textTertiary)
                Text(loc.s.summary(model.action(for: slot)))
                    .font(AppStyle.Typography.rowTitle)
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
            }
            .padding(AppStyle.Spacing.xSmall)
            .frame(width: 76, height: 76)
            .background(hovering && !selected ? AppColors.fillSecondaryHover : AppColors.fillSecondary,
                        in: RoundedRectangle(cornerRadius: AppStyle.Radius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: AppStyle.Radius.lg, style: .continuous)
                .strokeBorder(selected ? AppColors.actionPrimary : AppColors.borderSubtle, lineWidth: selected ? 1.5 : 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(loc.s.slotName(slot))
    }
}

private struct KnobView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var loc: Localizer
    let index: Int

    var body: some View {
        VStack(spacing: AppStyle.Spacing.xSmall) {
            HStack(spacing: AppStyle.Spacing.xSmall) {
                arrow(.knobLeft(index), icon: "arrow.counterclockwise")
                Button {
                    model.selectedSlot = .knobPress(index)
                } label: {
                    ZStack {
                        Circle().fill(AppColors.actionPrimary)
                        Circle().strokeBorder(AppColors.onActionPrimary.opacity(0.25), lineWidth: 1)
                            .padding(AppStyle.Spacing.xxSmallPlus)
                        Capsule().fill(AppColors.onActionPrimary).frame(width: 3, height: 10)
                            .offset(y: -15)
                    }
                    .frame(width: 56, height: 56)
                    .overlay(Circle().strokeBorder(model.selectedSlot == .knobPress(index) ? AppColors.actionPrimary : .clear,
                                                   lineWidth: 1.5)
                        .padding(-AppStyle.Spacing.xxSmall))
                }
                .buttonStyle(.plain)
                .help(loc.s.slotName(.knobPress(index)) + " — " + loc.s.summary(model.action(for: .knobPress(index))))
                arrow(.knobRight(index), icon: "arrow.clockwise")
            }
            Text(loc.s.knob(index + 1)).font(AppStyle.Typography.micro).foregroundStyle(AppColors.textTertiary)
        }
    }

    private func arrow(_ slot: Slot, icon: String) -> some View {
        Button {
            model.selectedSlot = slot
        } label: {
            Label(loc.s.slotName(slot), systemImage: icon).labelStyle(.iconOnly)
        }
        .buttonStyle(.app(model.selectedSlot == slot ? .primary : .secondary, size: .small, width: .square))
        .help(loc.s.slotName(slot) + " — " + loc.s.summary(model.action(for: slot)))
    }
}
