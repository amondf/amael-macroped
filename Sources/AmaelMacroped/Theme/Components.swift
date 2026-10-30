import SwiftUI

/// Grouped content: `surfaceCard` with a 0.5pt hairline instead of a shadow.
struct Card<Content: View>: View {
    var padding: CGFloat = AppStyle.Spacing.medium
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.surfaceCard, in: RoundedRectangle(cornerRadius: AppStyle.Radius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: AppStyle.Radius.lg, style: .continuous)
                .strokeBorder(AppColors.borderSubtle, lineWidth: 0.5))
    }
}

/// Group header above a card.
struct SectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack {
            Text(title).font(AppStyle.Typography.headline).foregroundStyle(AppColors.textPrimary)
            Spacer()
            trailing
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String) {
        self.title = title
        trailing = EmptyView()
    }
}

/// Hairline separator inside a card.
struct CardDivider: View {
    var body: some View {
        Rectangle().fill(AppColors.borderSubtle).frame(height: 0.5)
    }
}

/// A row inside a settings-like card: title and caption on the left, a control on the right.
struct CardRow<Control: View>: View {
    let title: String
    var caption: String?
    @ViewBuilder let control: Control

    var body: some View {
        HStack(alignment: .center, spacing: AppStyle.Spacing.medium) {
            VStack(alignment: .leading, spacing: AppStyle.Spacing.xxxSmall) {
                Text(title).font(AppStyle.Typography.rowTitle).foregroundStyle(AppColors.textPrimary)
                if let caption {
                    Text(caption).font(AppStyle.Typography.callout).foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: AppStyle.Spacing.small)
            control
        }
    }
}

/// Segmented control: a value-holding control, so a rounded rectangle (`md`), not a pill.
struct SegmentedControl<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let title: (Value) -> String

    var body: some View {
        HStack(spacing: AppStyle.Spacing.xxxSmall) {
            ForEach(options, id: \.self) { option in
                let selected = option == selection
                Button {
                    selection = option
                } label: {
                    Text(title(option))
                        .font(selected ? AppStyle.Typography.headline : AppStyle.Typography.body)
                        .foregroundStyle(selected ? AppColors.textPrimary : AppColors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppStyle.Control.height - AppStyle.Spacing.xxSmall)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: AppStyle.Radius.sm, style: .continuous)
                                    .fill(AppColors.surfaceRaised)
                                    .overlay(RoundedRectangle(cornerRadius: AppStyle.Radius.sm, style: .continuous)
                                        .strokeBorder(AppColors.borderSubtle, lineWidth: 0.5))
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppStyle.Spacing.xxxSmall)
        .background(AppColors.fillSecondary, in: RoundedRectangle(cornerRadius: AppStyle.Radius.md, style: .continuous))
    }
}

/// Dropdown field: a value-holding control shown as an `md` rounded rectangle with a chevron.
struct Dropdown<Content: View>: View {
    let value: String
    var minWidth: CGFloat = 160
    @ViewBuilder let content: Content

    var body: some View {
        Menu {
            content
        } label: {
            HStack(spacing: AppStyle.Spacing.xSmall) {
                Text(value).font(AppStyle.Typography.body).foregroundStyle(AppColors.textPrimary).lineLimit(1)
                Spacer(minLength: AppStyle.Spacing.xSmall)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppColors.textTertiary)
            }
            .padding(.horizontal, AppStyle.Spacing.small)
            .frame(minWidth: minWidth, minHeight: AppStyle.Control.height)
            .background(AppColors.fillSecondary, in: RoundedRectangle(cornerRadius: AppStyle.Radius.md, style: .continuous))
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

/// Text field drawn as a value-holding control.
struct FieldBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(AppStyle.Typography.body)
            .foregroundStyle(AppColors.textPrimary)
            .padding(.horizontal, AppStyle.Spacing.small)
            .frame(height: AppStyle.Control.height)
            .background(AppColors.fillSecondary, in: RoundedRectangle(cornerRadius: AppStyle.Radius.md, style: .continuous))
    }
}

/// Status tag (badge) with the status fill/text pairs.
struct StatusTag: View {
    enum Kind { case safe, unsure }
    let kind: Kind
    let text: String

    var body: some View {
        HStack(spacing: AppStyle.Spacing.xxSmallPlus) {
            Circle().fill(foreground).frame(width: 6, height: 6)
            Text(text).font(AppStyle.Typography.metadataEmphasis).foregroundStyle(foreground).lineLimit(1)
        }
        .padding(.horizontal, AppStyle.Spacing.xSmall)
        .padding(.vertical, AppStyle.Spacing.xxSmall)
        .background(fill, in: Capsule(style: .continuous))
    }

    private var foreground: Color { kind == .safe ? AppColors.statusSafeText : AppColors.statusUnsureText }
    private var fill: Color { kind == .safe ? AppColors.statusSafeFill : AppColors.statusUnsureFill }
}
