// Design tokens adapted from Purge (https://github.com/jithin-sabu/purge-app),
// Copyright (c) 2026 Jithin Sabu, MIT License. See THIRD_PARTY_NOTICES.md.

import AppKit
import SwiftUI

/// Every colour in the app. The neutrals are a warm graphite: low-chroma greys leaning slightly
/// yellow. Tokens are named by job, so views never use raw hex or SwiftUI's `.secondary` greys.
enum AppColors {
    // MARK: Text

    static let textPrimary = Color(light: 0x2E2D2B, dark: 0xECEAE6)
    static let textSecondary = Color(light: 0x64625E, dark: 0xA6A39D)
    /// Icons, chevrons, placeholders. Never a sentence.
    static let textTertiary = Color(light: 0x85827C, dark: 0x807D78)

    // MARK: Surfaces

    static let surfaceBase = Color(light: 0xF6F5F3, dark: 0x171615)
    static let surfaceCard = Color(light: 0xFFFFFF, dark: 0x1E1D1C)
    static let surfaceRaised = Color(light: 0xFFFFFF, dark: 0x2B2A28)
    static let surfaceCardHover = Color(light: 0xF4F2EF, dark: 0x2A2927)

    // MARK: Fills

    static let fillSecondary = Color(light: 0xEFEDEA, dark: 0x282725)
    static let fillSecondaryHover = Color(light: 0xE8E6E2, dark: 0x2F2E2C)
    static let fillSecondaryPressed = Color(light: 0xDFDCD8, dark: 0x373533)

    // MARK: Borders

    static let borderSubtle = Color(light: 0xE6E3DF, dark: 0x302F2D)
    static let borderStrong = Color(light: 0xD5D2CD, dark: 0x3D3B38)

    // MARK: Actions

    /// The one main action on a screen; also the selection and focus accent.
    static let actionPrimary = Color(light: 0x353431, dark: 0xECEAE6)
    static let actionPrimaryHover = Color(light: 0x42403D, dark: 0xF6F4F1)
    static let actionPrimaryPressed = Color(light: 0x2A2927, dark: 0xD8D5D0)
    static let onActionPrimary = Color(light: 0xFFFFFF, dark: 0x171615)
    static let actionDestructive = Color(light: 0xD1312A, dark: 0xD9372D)
    static let actionDestructiveHover = Color(light: 0xBC2B25, dark: 0xE2453B)
    static let actionDestructivePressed = Color(light: 0xA92620, dark: 0xC4302A)

    // MARK: Status

    static let statusSafeText = Color(light: 0x1F7A35, dark: 0x5FD36B)
    static let statusSafeFill = Color(light: 0xE6F4EA, dark: 0x1B2E22)
    static let statusDangerText = Color(light: 0xB4302A, dark: 0xF47468)
    static let statusDangerFill = Color(light: 0xFBE8E5, dark: 0x321B19)
    static let statusUnsureText = Color(light: 0x5A5853, dark: 0xA9A6A0)
    static let statusUnsureFill = Color(light: 0xEFEDEA, dark: 0x282725)

    // MARK: Accent

    /// Warm amber, used sparingly (the coffee cup).
    static let accentCelebrate = Color(light: 0xD18F00, dark: 0xFFC70D)
}

private extension NSColor {
    static func hex(_ value: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: 1)
    }

    convenience init(light: UInt32, dark: UInt32) {
        let light = NSColor.hex(light), dark = NSColor.hex(dark)
        self.init(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        }
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(light: light, dark: dark))
    }
}
