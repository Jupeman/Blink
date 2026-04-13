import SwiftUI

struct SettingsView: View {
    @Environment(SettingsStore.self) private var store
    @State private var sshHosts: [SSHHost] = []

    var body: some View {
        TabView {
            DestinationsTab(sshHosts: sshHosts)
                .tabItem { Label("Destinations", systemImage: "server.rack") }
            NotificationsTab()
                .tabItem { Label("Notifications", systemImage: "bell") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 360)
        .onAppear { sshHosts = SSHConfigParser.parseUserConfig() }
    }
}

private struct DestinationsTab: View {
    @Environment(SettingsStore.self) private var store
    let sshHosts: [SSHHost]
    @State private var selectedID: UUID?
    @State private var editingName = ""
    @State private var editingHost = ""
    @State private var editingPath = ""

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                List(store.destinations, selection: $selectedID) { dest in
                    HStack {
                        Text(dest.name)
                        if dest.isDefault {
                            Text("Default").font(.caption2)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(.blue.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    .tag(dest.id)
                }
                .frame(minWidth: 160)

                Divider()

                HStack {
                    Button(action: addPreset) { Image(systemName: "plus") }
                    Button(action: removeSelected) { Image(systemName: "minus") }
                        .disabled(selectedID == nil || store.destinations.count <= 1)
                    Spacer()
                }
                .padding(8)
            }

            Form {
                TextField("Name", text: $editingName)
                Picker("Host", selection: $editingHost) {
                    ForEach(sshHosts, id: \.alias) { host in
                        Text(host.alias).tag(host.alias)
                    }
                    if !sshHosts.contains(where: { $0.alias == editingHost }) && !editingHost.isEmpty {
                        Text(editingHost).tag(editingHost)
                    }
                }
                if let sshHost = sshHosts.first(where: { $0.alias == editingHost }) {
                    LabeledContent("Resolved") { Text(sshHost.displayName).foregroundStyle(.secondary) }
                    LabeledContent("Port") { Text("\(sshHost.effectivePort)").foregroundStyle(.secondary) }
                }
                TextField("Remote Path", text: $editingPath)

                HStack {
                    Button("Set as Default") {
                        saveEdits()
                        if let dest = selectedDestination { store.setDefault(dest) }
                    }
                    .disabled(selectedDestination?.isDefault == true)
                    Spacer()
                    Button("Save") { saveEdits() }
                }
            }
            .padding()
            .frame(minWidth: 280)
        }
        .onChange(of: selectedID) { _, newValue in loadSelected(newValue) }
        .onAppear { selectedID = store.destinations.first?.id }
    }

    private var selectedDestination: Destination? {
        store.destinations.first { $0.id == selectedID }
    }

    private func loadSelected(_ id: UUID?) {
        guard let dest = store.destinations.first(where: { $0.id == id }) else { return }
        editingName = dest.name
        editingHost = dest.host
        editingPath = dest.remotePath
    }

    private func saveEdits() {
        guard var dest = selectedDestination else { return }
        dest.name = editingName
        dest.host = editingHost
        dest.remotePath = editingPath
        store.updateDestination(dest)
    }

    private func addPreset() {
        let dest = Destination(name: "New Destination", host: "", remotePath: "/")
        store.addDestination(dest)
        selectedID = dest.id
    }

    private func removeSelected() {
        guard let id = selectedID, let dest = store.destinations.first(where: { $0.id == id }) else { return }
        store.removeDestination(dest)
        selectedID = store.destinations.first?.id
    }
}

private struct NotificationsTab: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Form {
            Toggle("Show notification when transfer completes", isOn: $store.notificationsEnabled)
        }
        .padding()
    }
}

private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
            Text("Blink").font(.title).fontWeight(.bold)
            Text("Version 1.0.0").foregroundStyle(.secondary)
            Text("A native macOS app for SCP file transfers.")
            Text("Cast Blink. File appears.")
                .italic().foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
