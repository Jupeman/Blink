import SwiftUI
import UniformTypeIdentifiers

struct DropTargetView: View {
    @Environment(TransferManager.self) private var manager
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Drop files here or click to browse")
                .font(.title3)
                .foregroundStyle(.secondary)
            Button("Choose Files...") { openFilePicker() }
                .controlSize(.large)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                .foregroundStyle(isTargeted ? AnyShapeStyle(.blue) : AnyShapeStyle(.quaternary))
                .padding(16)
        }
        .background(isTargeted ? Color.blue.opacity(0.05) : .clear)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
            return true
        }
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowedContentTypes = [.item]
        if panel.runModal() == .OK { manager.addFiles(panel.urls) }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                guard let data = data as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                Task { @MainActor in manager.addFiles([url]) }
            }
        }
    }
}
