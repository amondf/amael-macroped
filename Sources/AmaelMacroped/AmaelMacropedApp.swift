import AppKit
import MacropedKit
import SwiftUI

@main
struct AmaelMacropedApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel()
    @StateObject private var loc = Localizer()

    var body: some Scene {
        WindowGroup("Amael Macroped") {
            ContentView()
                .environmentObject(model)
                .environmentObject(loc)
                .environment(\.locale, loc.language.locale)
                .frame(minWidth: 860, minHeight: 560)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(loc.s.openProfile) { model.openProfile() }.keyboardShortcut("o")
                Button(loc.s.saveProfileAs) { model.saveProfileAs() }.keyboardShortcut("s")
            }
            CommandMenu(loc.s.keyboardMenu) {
                Button(loc.s.writeToDevice) { model.writeToDevice() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!model.isConnected || model.busy)
                Button(loc.s.readFromDevice) { model.readFromDevice() }
                    .keyboardShortcut("r")
                    .disabled(!model.isConnected || model.busy)
                Divider()
                Button(loc.s.restoreDefault) { model.resetToDefault() }
            }
        }

        Settings {
            SettingsView()
                .environmentObject(loc)
                .environment(\.locale, loc.language.locale)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when launched as a bare executable (swift run) instead of the .app bundle.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let path = ProcessInfo.processInfo.environment["AMAEL_SNAPSHOT"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { Self.snapshot(to: path) }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// Debug aid: renders the main window to a PNG without needing screen-recording permission.
    private static func snapshot(to path: String) {
        guard let view = NSApp.windows.first(where: \.isVisible)?.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }
}
