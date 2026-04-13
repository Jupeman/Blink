import SwiftUI

@main
struct BlinkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var transferManager = TransferManager()
    @State private var settingsStore = SettingsStore()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(transferManager)
                .environment(settingsStore)
                .onAppear {
                    appDelegate.onFilesDropped = { urls in
                        Task { @MainActor in
                            transferManager.addFiles(urls)
                        }
                    }
                    NotificationService.requestPermission()
                }
        }
        .defaultSize(width: 560, height: 480)

        Settings {
            SettingsView()
                .environment(settingsStore)
        }
    }
}
