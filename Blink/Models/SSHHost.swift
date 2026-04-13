import Foundation

struct SSHHost: Equatable, Sendable {
    let alias: String
    let hostName: String?
    let user: String?
    let port: Int?

    var displayName: String {
        if let user = user, let hostName = hostName {
            return "\(user)@\(hostName)"
        } else if let hostName = hostName {
            return hostName
        }
        return alias
    }

    var effectivePort: Int { port ?? 22 }
}
