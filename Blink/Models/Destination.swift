import Foundation

struct Destination: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: UUID
    var name: String
    var host: String
    var remotePath: String
    var isDefault: Bool

    init(id: UUID = UUID(), name: String, host: String, remotePath: String, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.host = host
        self.remotePath = remotePath
        self.isDefault = isDefault
    }

    var scpTarget: String {
        let path = remotePath.hasSuffix("/") ? remotePath : remotePath + "/"
        return "\(host):\(path)"
    }
}
