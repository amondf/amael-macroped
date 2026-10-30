// Design tokens adapted from Purge (https://github.com/jithin-sabu/purge-app),
// Copyright (c) 2026 Jithin Sabu, MIT License. See THIRD_PARTY_NOTICES.md.

import AppKit
import CoreText
import SwiftUI

enum AppStyle {
    /// Corner radii. Actions are capsules and take no radius token.
    enum Radius {
        /// Badges, small tiles.
        static let xs: CGFloat = 4
        /// Chips, modifier keys, thumbnails.
        static let sm: CGFloat = 6
        /// Controls that hold a value: pickers, fields, segmented controls.
        static let md: CGFloat = 8
        /// Cards, list rows, sheets.
        static let lg: CGFloat = 14
        static let xl: CGFloat = 18
    }

    enum Spacing {
        static let xxxSmall: CGFloat = 2
        static let xxSmall: CGFloat = 4
        static let xxSmallPlus: CGFloat = 6
        static let xSmall: CGFloat = 8
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xLarge: CGFloat = 32
    }

    enum Control {
        static let height: CGFloat = 28
    }

    /// One step of the type scale: family, size, weight and the tracking that goes with the size.
    struct TextStyle: Hashable {
        enum Family: Hashable { case onest, rounded, monospaced }

        let family: Family
        let size: CGFloat
        let weight: Font.Weight
        let tracking: CGFloat

        var font: Font {
            switch family {
            case .onest: return AppFonts.onest(size: size, weight: weight)
            case .rounded: return .system(size: size, weight: weight, design: .rounded)
            case .monospaced: return .system(size: size, weight: weight, design: .monospaced)
            }
        }

        func weight(_ weight: Font.Weight) -> TextStyle {
            TextStyle(family: family, size: size, weight: weight, tracking: tracking)
        }

        /// SF Rounded at this size, for figures.
        var numbers: TextStyle { TextStyle(family: .rounded, size: size, weight: weight, tracking: 0) }

        func monospaced() -> TextStyle { TextStyle(family: .monospaced, size: size, weight: weight, tracking: 0) }
    }

    enum Typography {
        static let title = onest(26, .semibold, tracking: 0)
        static let pageTitle = onest(20, .semibold, tracking: 0)
        static let sectionTitle = onest(15, .semibold, tracking: 0.1)
        static let headline = onest(13, .semibold, tracking: 0.15)
        static let body = onest(13, tracking: 0.15)
        static let rowTitle = onest(13, .medium, tracking: 0.15)
        static let callout = onest(12, tracking: 0.25)
        static let metadata = onest(11, tracking: 0.3)
        static let metadataEmphasis = onest(11, .medium, tracking: 0.3)
        static let micro = onest(10, .semibold, tracking: 0.4)

        private static func onest(_ size: CGFloat, _ weight: Font.Weight = .regular, tracking: CGFloat) -> TextStyle {
            TextStyle(family: .onest, size: size, weight: weight, tracking: tracking)
        }
    }
}

extension View {
    /// Sets a type-scale style: its font and its tracking.
    func font(_ style: AppStyle.TextStyle) -> some View {
        font(style.font).tracking(style.tracking)
    }
}

extension Text {
    func font(_ style: AppStyle.TextStyle) -> Text {
        font(style.font).tracking(style.tracking)
    }
}

/// Onest for text (SIL Open Font License, see Resources/Fonts/Onest-OFL.txt), SF Rounded for figures.
/// The bundled copy has its digits removed, so numbers fall back to the system font.
enum AppFonts {
    private static var registration: Bool?

    @discardableResult
    static func register() -> Bool {
        if let registration { return registration }
        var error: Unmanaged<CFError>?
        let ok = fontURL.map { CTFontManagerRegisterFontsForURL($0 as CFURL, .process, &error) } ?? false
        registration = ok
        return ok
    }

    /// The .app bundle's copy, or the repository's when running with `swift run`.
    private static var fontURL: URL? {
        if let url = Bundle.main.url(forResource: "OnestText", withExtension: "ttf") { return url }
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let dev = repo.appendingPathComponent("Resources/Fonts/OnestText.ttf")
        return FileManager.default.fileExists(atPath: dev.path) ? dev : nil
    }

    static func onest(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        register() ? Font.custom("Onest", size: size).weight(weight) : Font.system(size: size, weight: weight)
    }
}
