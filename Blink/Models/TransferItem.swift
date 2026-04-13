import Foundation

enum TransferStatus: Equatable, Sendable {
    case queued
    case transferring
    case completed
    case failed(String)
    case cancelled
}

struct TransferItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let url: URL
    let fileName: String
    let fileSize: Int64
    let isDirectory: Bool
    var status: TransferStatus
    var progress: TransferProgress?

    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.fileName = url.lastPathComponent
        self.isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        self.fileSize = Int64(size)
        self.status = .queued
        self.progress = nil
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    static func == (lhs: TransferItem, rhs: TransferItem) -> Bool {
        lhs.id == rhs.id && lhs.status == rhs.status && lhs.progress == rhs.progress
    }
}
