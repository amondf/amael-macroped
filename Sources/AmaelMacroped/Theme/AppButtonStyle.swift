// Adapted from Purge's PurgeButtonStyle (https://github.com/jithin-sabu/purge-app),
// Copyright (c) 2026 Jithin Sabu, MIT License. See THIRD_PARTY_NOTICES.md.

import SwiftUI

/// The one button style for every action. Every action is a pill; controls that hold a value use
/// a rounded rectangle instead, so shape alone tells an action from a setting.
struct AppButtonStyle: ButtonStyle {
    enum Role { case primary, secondary, destructive, quiet, soft }
    enum Size { case small, regular, large }
    enum Width { case fit, fill, square }

    var role: Role = .secondary
    var size: Size = .regular
    var width: Width = .fit

    func makeBody(configuration: Configuration) -> some View {
        AppButtonBody(configuration: configuration, role: role, size: size, width: width)
    }
}

extension ButtonStyle where Self == AppButtonStyle {
    static func app(_ role: AppButtonStyle.Role = .secondary, size: AppButtonStyle.Size = .regular,
                    width: AppButtonStyle.Width = .fit) -> AppButtonStyle {
        AppButtonStyle(role: role, size: size, width: width)
    }
}

private struct AppButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let role: AppButtonStyle.Role
    let size: AppButtonStyle.Size
    let width: AppButtonStyle.Width

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        sizedLabel
            .font(font)
            .foregroundStyle(foreground)
            .tint(foreground)
            .lineLimit(1)
            .padding(.horizontal, width == .square ? 0 : horizontalPadding)
            .frame(height: height)
            .background(background, in: Capsule(style: .continuous))
            .overlay {
                if role == .secondary {
                    Capsule(style: .continuous).strokeBorder(AppColors.borderStrong, lineWidth: 1)
                }
            }
            .contentShape(Capsule(style: .continuous))
            .opacity(isEnabled ? 1 : 0.45)
            .onHover { isHovering = $0 }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isHovering)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }

    @ViewBuilder
    private var sizedLabel: some View {
        switch width {
        case .fit: configuration.label
        case .fill: configuration.label.frame(maxWidth: .infinity)
        case .square: configuration.label.frame(width: height)
        }
    }

    private var height: CGFloat {
        switch size {
        case .small: return 24
        case .regular: return 30
        case .large: return 38
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .small: return 10
        case .regular: return 14
        case .large: return 20
        }
    }

    private var font: AppStyle.TextStyle {
        switch size {
        case .small: return AppStyle.Typography.callout.weight(.semibold)
        case .regular: return AppStyle.Typography.headline
        case .large: return AppStyle.Typography.sectionTitle
        }
    }

    private var isActive: Bool { isEnabled && isHovering }

    private var foreground: Color {
        switch role {
        case .primary: return AppColors.onActionPrimary
        case .secondary: return AppColors.textPrimary
        case .destructive: return .white
        case .quiet, .soft: return isActive ? AppColors.textPrimary : AppColors.textSecondary
        }
    }

    private var background: Color {
        let pressed = configuration.isPressed
        switch role {
        case .primary:
            return pressed ? AppColors.actionPrimaryPressed : (isActive ? AppColors.actionPrimaryHover : AppColors.actionPrimary)
        case .secondary, .soft:
            return pressed ? AppColors.fillSecondaryPressed : (isActive ? AppColors.fillSecondaryHover : AppColors.fillSecondary)
        case .destructive:
            return pressed ? AppColors.actionDestructivePressed : (isActive ? AppColors.actionDestructiveHover : AppColors.actionDestructive)
        case .quiet:
            return pressed ? AppColors.fillSecondaryPressed : (isActive ? AppColors.fillSecondaryHover : .clear)
        }
    }
}
