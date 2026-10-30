import AppKit
import MacropedKit
import SwiftUI

@main
struct AmaelMacropedApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("Amael Macroped") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 860, minHeight: 560)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Abrir perfil…") { model.openProfile() }.keyboardShortcut("o")
                Button("Salvar perfil como…") { model.saveProfileAs() }.keyboardShortcut("s")
            }
            CommandMenu("Teclado") {
                Button("Gravar no teclado") { model.writeToDevice() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!model.isConnected || model.busy)
                Button("Ler do teclado") { model.readFromDevice() }
                    .keyboardShortcut("r")
                    .disabled(!model.isConnected || model.busy)
                Divider()
                Button("Restaurar perfil padrão") { model.resetToDefault() }
            }
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

    /// Debug aid: renders the main window to a PNG without needing screen-recording permission.
    private static func snapshot(to path: String) {
        guard let view = NSApp.windows.first(where: \.isVisible)?.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
