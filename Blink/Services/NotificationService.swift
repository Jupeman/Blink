import Foundation
import UserNotifications

enum NotificationService {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func sendTransferComplete(fileCount: Int, totalSize: Int64, destinationHost: String) {
        let content = UNMutableNotificationContent()
        content.title = "Transfer Complete"
        let sizeStr = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        content.body = "Blinked \(fileCount) file\(fileCount == 1 ? "" : "s") (\(sizeStr)) to \(destinationHost)."
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
