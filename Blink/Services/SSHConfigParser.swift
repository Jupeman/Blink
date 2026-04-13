import Foundation

enum SSHConfigParser {
    static func parse(content: String) -> [SSHHost] {
        var hosts: [SSHHost] = []
        var currentAlias: String?
        var currentHostName: String?
        var currentUser: String?
        var currentPort: Int?

        func flushHost() {
            if let alias = currentAlias, !alias.contains("*") {
                hosts.append(SSHHost(alias: alias, hostName: currentHostName, user: currentUser, port: currentPort))
            }
            currentAlias = nil
            currentHostName = nil
            currentUser = nil
            currentPort = nil
        }

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            let parts = trimmed.split(separator: " ", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }

            switch parts[0].lowercased() {
            case "host":
                flushHost()
                currentAlias = parts[1]
            case "hostname":
                currentHostName = parts[1]
            case "user":
                currentUser = parts[1]
            case "port":
                currentPort = Int(parts[1])
            default: break
            }
        }
        flushHost()
        return hosts
    }

    static func parse(fileURL: URL) throws -> [SSHHost] {
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        return parse(content: content)
    }

    static func parseUserConfig() -> [SSHHost] {
        let configURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh/config")
        return (try? parse(fileURL: configURL)) ?? []
    }
}
