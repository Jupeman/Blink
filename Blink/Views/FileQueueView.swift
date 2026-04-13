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
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = true
                    panel.canChooseFiles = true
                    panel.canChooseDirectories = true
                    panel.allowedContentTypes = [.item]
                    if panel.runModal() == .OK { manager.addFiles(panel.urls) }
                } label: {
                    Image(systemName: "plus")
                }
                .help("Add more files")
            }
        }
    }
}
