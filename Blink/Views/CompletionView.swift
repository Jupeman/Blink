import SwiftUI

struct CompletionView: View {
    @Environment(TransferManager.self) private var manager

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: statusIcon)
                .font(.system(size: 48))
                .foregroundStyle(statusColor)

            if let summary = manager.summary {
                Text(headlineText(summary))
                    .font(.title2).fontWeight(.semibold)
                VStack(spacing: 4) {
                    Text("\(ByteCountFormatter.string(fromByteCount: summary.totalBytes, countStyle: .file)) transferred")
                    Text("in \(formattedElapsed(summary.elapsed))")
                }
                .foregroundStyle(.secondary)

                if summary.filesFailed > 0 {
                    Text("\(summary.filesFailed) file\(summary.filesFailed == 1 ? "" : "s") failed")
                        .foregroundStyle(.red)

                    ForEach(manager.items.filter {
                        if case .failed = $0.status { return true }
                        return false
                    }) { item in
                        if case .failed(let msg) = item.status {
                            Text(msg)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
            }

            Spacer()

            Button("Done") { manager.reset() }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var statusIcon: String {
        guard let s = manager.summary else { return "checkmark.circle" }
        return s.filesFailed == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    private var statusColor: Color {
        guard let s = manager.summary else { return .green }
        return s.filesFailed == 0 ? .green : .orange
    }

    private func headlineText(_ s: TransferSummary) -> String {
        s.filesFailed == 0
            ? "Blinked \(s.filesTransferred) file\(s.filesTransferred == 1 ? "" : "s")"
            : "Transfer completed with errors"
    }

    private func formattedElapsed(_ interval: TimeInterval) -> String {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute, .second]
        f.unitsStyle = .abbreviated
        return f.string(from: interval) ?? "\(Int(interval))s"
    }
}
