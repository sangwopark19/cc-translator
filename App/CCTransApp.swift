import SwiftUI

@main
struct CCTransApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("cctrans", systemImage: "character.bubble") {
            SettingsLink { Text("환경설정…") }
                .keyboardShortcut(",")
            Divider()
            Button("종료") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        Settings {
            SettingsView()
        }
    }
}
