import SwiftUI

struct MainView: View {
    @Environment(TransferManager.self) private var manager
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        switch manager.phase {
        case .idle: DropTargetView()
        case .queued: FileQueueView()
        case .transferring: TransferProgressView()
        case .completed: CompletionView()
        }
    }
}
