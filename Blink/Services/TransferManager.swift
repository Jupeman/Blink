import Foundation
import SwiftUI

enum AppPhase: Equatable {
    case idle
    case queued
    case transferring
    case completed
}

struct TransferSummary: Equatable {
    let filesTransferred: Int
    let filesFailed: Int
    let totalBytes: Int64
    let elapsed: TimeInterval
}

@Observable
@MainActor
final class TransferManager {
    var phase: AppPhase = .idle
    var items: [TransferItem] = []
    var currentIndex: Int = 0
    var summary: TransferSummary?

    private let engine = SCPTransferEngine()
    private var transferTask: Task<Void, Never>?
    private var startTime: Date?

    var currentItem: TransferItem? {
        guard currentIndex < items.count else { return nil }
        return items[currentIndex]
    }

    var completedCount: Int {
        items.filter { $0.status == .completed }.count
    }

    var totalQueuedBytes: Int64 {
        items.reduce(0) { $0 + $1.fileSize }
    }

    func addFiles(_ urls: [URL]) {
        let newItems = urls.map { TransferItem(url: $0) }
        items.append(contentsOf: newItems)
        if phase == .idle || phase == .completed {
            phase = .queued
        }
    }

    func clearQueue() {
        items.removeAll()
        phase = .idle
        summary = nil
    }

    func startTransfer(to destination: Destination) {
        guard !items.isEmpty else { return }
        phase = .transferring
        currentIndex = 0
        startTime = Date()

        transferTask = Task {
            for i in items.indices {
                guard !Task.isCancelled else { break }
                currentIndex = i
                items[i].status = .transferring

                do {
                    let stream = engine.transfer(
                        file: items[i].url,
                        to: destination,
                        isDirectory: items[i].isDirectory
                    )
                    for try await progress in stream {
                        items[i].progress = progress
                    }
                    items[i].status = .completed
                } catch is CancellationError {
                    items[i].status = .cancelled
                    break
                } catch let error as SCPError {
                    items[i].status = .failed(
                        error.errorDescription ?? error.localizedDescription
                    )
                } catch {
                    items[i].status = .failed(error.localizedDescription)
                }
            }

            let elapsed = startTime.map { Date().timeIntervalSince($0) } ?? 0
            summary = TransferSummary(
                filesTransferred: items.filter { $0.status == .completed }.count,
                filesFailed: items.filter {
                    if case .failed = $0.status { return true }
                    return false
                }.count,
                totalBytes: items
                    .filter { $0.status == .completed }
                    .reduce(0) { $0 + $1.fileSize },
                elapsed: elapsed
            )
            phase = .completed

            if let summary = self.summary, summary.filesTransferred > 0 {
                NotificationService.sendTransferComplete(
                    fileCount: summary.filesTransferred,
                    totalSize: summary.totalBytes,
                    destinationHost: destination.host
                )
            }
        }
    }

    func cancel() {
        transferTask?.cancel()
        engine.cancel()
        for i in items.indices where items[i].status == .transferring {
            items[i].status = .cancelled
        }
    }

    func reset() {
        items.removeAll()
        summary = nil
        currentIndex = 0
        phase = .idle
    }
}
