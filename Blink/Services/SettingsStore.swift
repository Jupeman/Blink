import Foundation
import SwiftUI

@Observable
@MainActor
final class SettingsStore {
    private let defaults: UserDefaults
    private static let destinationsKey = "savedDestinations"
    private static let notificationsKey = "notificationsEnabled"

    var destinations: [Destination] {
        didSet { saveDestinations() }
    }

    var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Self.notificationsKey) }
    }

    var activeDestination: Destination? {
        destinations.first { $0.isDefault } ?? destinations.first
    }

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
        if let data = userDefaults.data(forKey: Self.destinationsKey),
           let decoded = try? JSONDecoder().decode([Destination].self, from: data),
           !decoded.isEmpty {
            self.destinations = decoded
        } else {
            self.destinations = [Self.defaultDestination]
        }
        if userDefaults.object(forKey: Self.notificationsKey) != nil {
            self.notificationsEnabled = userDefaults.bool(forKey: Self.notificationsKey)
        } else {
            self.notificationsEnabled = true
        }
    }

    func addDestination(_ destination: Destination) { destinations.append(destination) }

    func removeDestination(_ destination: Destination) {
        destinations.removeAll { $0.id == destination.id }
    }

    func updateDestination(_ destination: Destination) {
        if let i = destinations.firstIndex(where: { $0.id == destination.id }) { destinations[i] = destination }
    }

    func setDefault(_ destination: Destination) {
        for i in destinations.indices { destinations[i].isDefault = (destinations[i].id == destination.id) }
    }

    private func saveDestinations() {
        if let data = try? JSONEncoder().encode(destinations) { defaults.set(data, forKey: Self.destinationsKey) }
    }

    private static let defaultDestination = Destination(
        name: "Gandalf Movies", host: "gandalf", remotePath: "/srv/media/movies/", isDefault: true
    )
}
