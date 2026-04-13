import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var onFilesDropped: (([URL]) -> Void)?

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let urls = filenames.map { URL(fileURLWithPath: $0) }
        onFilesDropped?(urls)
        sender.reply(toOpenOrPrint: .success)
    }
}
