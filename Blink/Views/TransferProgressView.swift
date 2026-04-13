import SwiftUI

struct TransferProgressView: View {
    @Environment(TransferManager.self) private var manager

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Transferring \(manager.completedCount + 1) of \(manager.items.count)")
                    .fontWeight(.semibold)
                Spacer()
                Text(overallSizeText).foregroundStyle(.secondary)
            }
            .padding()
            .background(.bar)

            Divider()

            List {
                ForEach(manager.items) { item in
                    TransferItemRow(item: item)
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancel", role: .destructive) { manager.cancel() }
            }
            .padding()
        }
    }

    private var overallSizeText: String {
        let transferred = manager.items.filter { $0.status == .completed }.reduce(0) { $0 + $1.fileSize }
        let transferredStr = ByteCountFormatter.string(fromByteCount: transferred, countStyle: .file)
        let totalStr = ByteCountFormatter.string(fromByteCount: manager.totalQueuedBytes, countStyle: .file)
        return "\(transferredStr) / \(totalStr)"
    }
}

struct TransferItemRow: View {
    let item: TransferItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: statusIcon).foregroundStyle(statusColor)
                Text(item.fileName)
                    .fontWeight(item.status == .transferring ? .semibold : .regular)
                Spacer()
                Text(item.formattedSize).foregroundStyle(.secondary)
            }

            if item.status == .transferring {
                ProgressView(value: Double(item.progress?.percentage ?? 0), total: 100)
                HStack {
                    if let progress = item.progress {
                        Text(progress.transferred)
                        Text("at \(progress.speed)")
                        Spacer()
                        Text("\(progress.eta) remaining")
                    } else {
                        Text("Starting...")
                        Spacer()
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if case .failed(let message) = item.status {
                Text(message).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusIcon: String {
        switch item.status {
        case .queued: "circle"
        case .transferring: "arrow.up.circle.fill"
        case .completed: "checkmark.circle.fill"
        case .failed: "exclamationmark.circle.fill"
        case .cancelled: "xmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch item.status {
        case .queued: .secondary
        case .transferring: .blue
        case .completed: .green
        case .failed: .red
        case .cancelled: .orange
        }
    }
}
