import SwiftUI
import UniformTypeIdentifiers

struct FileQueueView: View {
    @Environment(TransferManager.self) private var manager
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        VStack(spacing: 0) {
            if let destination = settings.activeDestination {
                HStack {
                    Image(systemName: "server.rack")
                        .foregroundStyle(.secondary)
                    Text(destination.host).fontWeight(.semibold)
                    Text(":").foregroundStyle(.secondary)
                    Text(destination.remotePath).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding()
                .background(.bar)
            }

            Divider()

            List {
                ForEach(manager.items) { item in
                    HStack {
                        Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                            .foregroundStyle(.blue)
                        Text(item.fileName)
                        Spacer()
                        Text(item.formattedSize).foregroundStyle(.secondary)
                    }
                }
                .onDelete { indexSet in
                    manager.items.remove(atOffsets: indexSet)
                    if manager.items.isEmpty { manager.clearQueue() }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                for provider in providers {
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                        guard let data = data as? Data,
                              let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                        Task { @MainActor in manager.addFiles([url]) }
                    }
                }
                return true
            }

            Divider()

            HStack {
                Text("\(manager.items.count) file\(manager.items.count == 1 ? "" : "s")")
                    .foregroundStyle(.secondary)
                Text("(\(ByteCountFormatter.string(fromByteCount: manager.totalQueuedBytes, countStyle: .file)))")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear") { manager.clearQueue() }
                Button("Blink") {
                    if let dest = settings.activeDestination { manager.startTransfer(to: dest) }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(settings.activeDestination == nil)
            }
            .padding()
        }
    }
}
