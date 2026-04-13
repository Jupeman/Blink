import Foundation

enum SCPError: LocalizedError {
    case transferFailed(String)
    case cancelled
    case scpNotFound

    var errorDescription: String? {
        switch self {
        case .transferFailed(let msg):
            return msg
        case .cancelled:
            return "Transfer was cancelled."
        case .scpNotFound:
            return "The scp binary was not found. Install Xcode command line tools."
        }
    }
}

final class SCPTransferEngine: @unchecked Sendable {
    private let scpPath: String
    private let processLock = NSLock()
    private var _currentProcess: Process?

    private var currentProcess: Process? {
        get { processLock.withLock { _currentProcess } }
        set { processLock.withLock { _currentProcess = newValue } }
    }

    init(scpPath: String = "/usr/bin/scp") {
        self.scpPath = scpPath
    }

    func transfer(
        file: URL,
        to destination: Destination,
        isDirectory: Bool
    ) -> AsyncThrowingStream<TransferProgress, Error> {
        AsyncThrowingStream { continuation in
            let scpPath = self.scpPath
            guard FileManager.default.fileExists(atPath: scpPath) else {
                continuation.finish(throwing: SCPError.scpNotFound)
                return
            }

            let filePath = file.path
            let scpTarget = destination.scpTarget

            // Use `script` to wrap SCP in a PTY. script allocates its own
            // PTY for the child command and copies output to its stdout.
            // This avoids forkpty issues inside the app process.
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/script")

                // script -q /dev/null <command> runs command in a PTY,
                // writes PTY output to stdout, discards the script file
                var scpArgs: [String] = [scpPath]
                scpArgs.append("-o")
                scpArgs.append("BatchMode=yes")
                scpArgs.append("-o")
                scpArgs.append("ConnectTimeout=10")
                if isDirectory { scpArgs.append("-r") }
                scpArgs.append(filePath)
                scpArgs.append(scpTarget)

                // script args: -q (quiet) -F (flush) /dev/null scp-command...
                process.arguments = ["-q", "-F", "/dev/null"] + scpArgs

                // Set COLUMNS so scp formats progress to a known width
                var env = ProcessInfo.processInfo.environment
                env["COLUMNS"] = "120"
                env["TERM"] = "xterm-256color"
                process.environment = env

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                } catch {
                    continuation.finish(throwing: SCPError.transferFailed(
                        "Failed to launch: \(error.localizedDescription)"))
                    return
                }

                self?.currentProcess = process

                continuation.onTermination = { @Sendable _ in
                    process.terminate()
                }

                // Read from pipe on this thread
                let fh = pipe.fileHandleForReading
                let fd = fh.fileDescriptor
                let bufferSize = 4096
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
                defer { buffer.deallocate() }
                var accumulated = ""
                var errorOutput = ""

                while true {
                    let bytesRead = read(fd, buffer, bufferSize)
                    if bytesRead <= 0 { break }

                    let chunk = String(
                        bytes: UnsafeBufferPointer(start: buffer, count: bytesRead),
                        encoding: .utf8
                    ) ?? ""
                    accumulated += chunk

                    // Split on \r or \n
                    let lines = accumulated.components(
                        separatedBy: CharacterSet(charactersIn: "\r\n")
                    )
                    accumulated = lines.last ?? ""

                    for line in lines.dropLast() {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty { continue }
                        if let progress = SCPProgressParser.parse(line: line) {
                            continuation.yield(progress)
                        } else {
                            errorOutput += trimmed + "\n"
                        }
                    }

                    // Also try parsing accumulated (handles \r-only updates)
                    if !accumulated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        if let progress = SCPProgressParser.parse(line: accumulated) {
                            continuation.yield(progress)
                            accumulated = ""
                        }
                    }
                }

                process.waitUntilExit()
                self?.currentProcess = nil

                let exitCode = process.terminationStatus
                let allOutput = (errorOutput + accumulated)
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if exitCode == 0 {
                    continuation.finish()
                } else if process.terminationReason == .uncaughtSignal {
                    continuation.finish(throwing: SCPError.cancelled)
                } else {
                    let msg = Self.describeError(exitCode: exitCode, lastOutput: allOutput)
                    continuation.finish(throwing: SCPError.transferFailed(msg))
                }
            }
        }
    }

    func cancel() {
        currentProcess?.terminate()
    }

    private static func describeError(exitCode: Int32, lastOutput: String) -> String {
        let trimmed = lastOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()
        if lowered.contains("permission denied") {
            return "Permission denied on remote path. Check destination directory permissions."
        }
        if lowered.contains("no space left") {
            return "Remote disk is full. Free space on the destination server."
        }
        if lowered.contains("connection refused") || lowered.contains("could not resolve") {
            return "Could not connect to the server. Verify your SSH config and that the server is reachable."
        }
        if !trimmed.isEmpty { return trimmed }
        return "SCP exited with code \(exitCode)."
    }
}
