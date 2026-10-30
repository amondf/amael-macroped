import Foundation
import MacropedKit
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case portuguese = "pt-BR"
    case english = "en"
    case russian = "ru"
    case chinese = "zh-Hans"

    var id: String { rawValue }

    /// Name shown in the picker, always in the language itself.
    var nativeName: String {
        switch self {
        case .portuguese: return "Português (Brasil)"
        case .english: return "English"
        case .russian: return "Русский"
        case .chinese: return "简体中文"
        }
    }

    var strings: Strings {
        switch self {
        case .portuguese: return .portuguese
        case .english: return .english
        case .russian: return .russian
        case .chinese: return .chinese
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }

    /// First supported language in the user's macOS preferences (English otherwise).
    static func systemPreferred() -> AppLanguage {
        for id in Locale.preferredLanguages {
            if id.hasPrefix("pt") { return .portuguese }
            if id.hasPrefix("en") { return .english }
            if id.hasPrefix("ru") { return .russian }
            if id.hasPrefix("zh") { return .chinese }
        }
        return .english
    }
}

@MainActor
final class Localizer: ObservableObject {
    private static let defaultsKey = "appLanguage"

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Self.defaultsKey) }
    }

    var s: Strings { language.strings }

    init() {
        // AMAEL_LANG overrides the saved choice (handy for screenshots/tests).
        let saved = ProcessInfo.processInfo.environment["AMAEL_LANG"] ?? UserDefaults.standard.string(forKey: Self.defaultsKey)
        language = saved.flatMap(AppLanguage.init(rawValue:)) ?? AppLanguage.systemPreferred()
    }
}

/// Status / alert messages kept language-independent so they re-render when the language changes.
enum StatusMessage: Equatable {
    case searching
    case disconnectedHint
    case connected(String)
    case connectedLayout(String, Int, Int)
    case identifying
    case writing
    case writeSuccess
    case reading
    case readUnsupported
    case readDone(Int)
    case layerCopied(Int, Int)
    case profileSaved(String)
    case profileLoaded(String)
    case saveFailed(String)
    case invalidProfile(String)
    case deviceError(MacropedError)
    case failure(String)

    init(_ error: Error) {
        if let e = error as? MacropedError { self = .deviceError(e) } else { self = .failure(error.localizedDescription) }
    }
}

/// Every user-visible text of the app. Adding a field forces every language to translate it.
struct Strings {
    // General
    let appSubtitle: String
    let disconnected: String
    let keysKnobs: (Int, Int) -> String
    let donateHelp: String
    let settings: String
    let language: String
    let languageNote: String

    // Menus / footer
    let openProfile: String
    let saveProfileAs: String
    let keyboardMenu: String
    let restoreDefault: String
    let readFromDevice: String
    let writeToDevice: String

    // Layers
    let layer: (Int) -> String
    let copyToLayer: (Int) -> String
    let clearLayer: String

    // Lighting
    let lighting: String
    let configureLighting: String
    let effect: String
    let effectOff: String
    let effectN: (Int) -> String
    let color: String
    let lightingNote: String
    /// Red, orange, yellow, green, cyan, blue, purple.
    let colors: [String]

    // Pad
    let key: (Int) -> String
    let knob: (Int) -> String
    let left: String
    let press: String
    let right: String

    // Editor
    let selectSlotHint: String
    let action: String
    let kindNone: String
    let kindKeys: String
    let kindMedia: String
    let kindMouse: String
    let noAction: String
    let recordShortcut: String
    let recordingPrompt: String
    let addKey: String
    let emptyKeysHint: String
    let typeTextTitle: String
    let typeTextPlaceholder: String
    let convertToMacro: String
    let asciiOnly: String
    let modifiersOnly: String
    let remove: String
    /// letters, digits, special, symbols, navigation, function, keypad.
    let keyGroups: [String: String]
    let space: String
    let media: [MediaKey: String]
    let leftClick: String
    let middleClick: String
    let rightClick: String
    let scrollUp: String
    let scrollDown: String

    // Status
    let searching: String
    let disconnectedHint: String
    let connected: (String) -> String
    let connectedLayout: (String, Int, Int) -> String
    let identifying: String
    let writing: String
    let writeSuccess: String
    let reading: String
    let readUnsupported: String
    let readDone: (Int) -> String
    let layerCopied: (Int, Int) -> String
    let profileSaved: (String) -> String
    let profileLoaded: (String) -> String
    let saveFailed: (String) -> String
    let invalidProfile: (String) -> String

    // Device errors
    let errNotFound: String
    let errPermission: String
    let errOpen: (String) -> String
    let errWrite: (String) -> String
}

extension Strings {
    func slotName(_ slot: Slot) -> String {
        switch slot {
        case .key(let n): return key(n)
        case .knobLeft(let k): return "\(knob(k + 1)) ↺ \(left)"
        case .knobPress(let k): return "\(knob(k + 1)) ● \(press)"
        case .knobRight(let k): return "\(knob(k + 1)) ↻ \(right)"
        }
    }

    func colorName(_ c: LEDColor) -> String { colors[Int(c.rawValue) - 1] }

    func mediaName(_ m: MediaKey) -> String { media[m] ?? m.identifier }

    func mouseName(_ m: MouseAction) -> String {
        switch m {
        case .leftClick: return leftClick
        case .middleClick: return middleClick
        case .rightClick: return rightClick
        case .wheelUp: return scrollUp
        case .wheelDown: return scrollDown
        case .controlWheelUp: return "⌃ + \(scrollUp)"
        case .controlWheelDown: return "⌃ + \(scrollDown)"
        case .shiftWheelUp: return "⇧ + \(scrollUp)"
        case .shiftWheelDown: return "⇧ + \(scrollDown)"
        case .optionWheelUp: return "⌥ + \(scrollUp)"
        case .optionWheelDown: return "⌥ + \(scrollDown)"
        }
    }

    func keyGroup(_ id: String) -> String { keyGroups[id] ?? id }

    func keyName(_ code: UInt8) -> String { code == 0x2C ? space : HIDKeys.name(for: code) }

    func chordName(_ c: KeyChord) -> String { c.modifiers.symbols + (c.keyCode == 0 ? "" : keyName(c.keyCode)) }

    func summary(_ a: KeyAction) -> String {
        switch a {
        case .none: return "—"
        case .keys(let chords): return chords.isEmpty ? "—" : chords.map(chordName).joined(separator: " ")
        case .media(let m): return mediaName(m)
        case .mouse(let m): return mouseName(m)
        }
    }

    func status(_ m: StatusMessage) -> String {
        switch m {
        case .searching: return searching
        case .disconnectedHint: return disconnectedHint
        case .connected(let p): return connected(p)
        case .connectedLayout(let p, let k, let n): return connectedLayout(p, k, n)
        case .identifying: return identifying
        case .writing: return writing
        case .writeSuccess: return writeSuccess
        case .reading: return reading
        case .readUnsupported: return readUnsupported
        case .readDone(let n): return readDone(n)
        case .layerCopied(let a, let b): return layerCopied(a, b)
        case .profileSaved(let f): return profileSaved(f)
        case .profileLoaded(let f): return profileLoaded(f)
        case .saveFailed(let e): return saveFailed(e)
        case .invalidProfile(let e): return invalidProfile(e)
        case .deviceError(let e): return deviceError(e)
        case .failure(let e): return e
        }
    }

    func deviceError(_ e: MacropedError) -> String {
        func hex(_ r: Int32) -> String { String(format: "0x%08X", UInt32(bitPattern: r)) }
        switch e {
        case .notFound: return errNotFound
        case .permissionDenied: return errPermission
        case .openFailed(let r): return errOpen(hex(r))
        case .writeFailed(let r): return errWrite(hex(r))
        }
    }
}
