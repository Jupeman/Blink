import Foundation

// POSIX wait-status macros are C macros not available in Swift.
// These replicate the Darwin definitions.
private func posixWIFEXITED(_ status: Int32) -> Bool {
    (status & 0x7F) == 0
}

private func posixWEXITSTATUS(_ status: Int32) -> Int32 {
    (status >> 8) & 0xFF
}

private func posixWIFSIGNALED(_ status: Int32) -> Bool {
    (status & 0x7F) != 0 && (status & 0x7F) != 0x7F
}

enum SCPError: LocalizedError {
    case forkFailed
    case transferFailed(String)
    case cancelled
    case scpNotFound

    var errorDescription: String? {
        switch self {
        case .forkFailed:
            return "Failed to start the SCP process."
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
    private let pidLock = NSLock()
    private var _currentPID: pid_t = 0

    private var currentPID: pid_t {
        get { pidLock.withLock { _currentPID } }
        set { pidLock.withLock { _currentPID = newValue } }
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

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                var masterFD: Int32 = 0
                let pid = forkpty(&masterFD, nil, nil, nil)

                if pid == 0 {
                    // Child process: exec scp
                    var args = [scpPath]
                    if isDirectory { args.append("-r") }
                    args.append(filePath)
                    args.append(scpTarget)
                    let cArgs = args.map { strdup($0) } + [nil]
                    execvp(scpPath, cArgs)
                    _exit(1)
                } else if pid > 0 {
                    self?.currentPID = pid

                    continuation.onTermination = { @Sendable _ in
                        kill(pid, SIGTERM)
                    }

                    let bufferSize = 4096
                    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
                    defer { buffer.deallocate() }
                    var accumulated = ""

                    while true {
                        let bytesRead = read(masterFD, buffer, bufferSize)
                        if bytesRead <= 0 { break }
                        let chunk = String(
                            bytes: UnsafeBufferPointer(start: buffer, count: bytesRead),
                            encoding: .utf8
                        ) ?? ""
                        accumulated += chunk

                        let lines = accumulated.components(
                            separatedBy: CharacterSet(charactersIn: "\r\n")
                        )
                        accumulated = lines.last ?? ""

                        for line in lines.dropLast() {
                            if let progress = SCPProgressParser.parse(line: line) {
                                continuation.yield(progress)
                            }
                        }
                    }

                    close(masterFD)

                    var status: Int32 = 0
                    waitpid(pid, &status, 0)
                    self?.currentPID = 0

                    if posixWIFEXITED(status) && posixWEXITSTATUS(status) == 0 {
                        continuation.finish()
                    } else if posixWIFSIGNALED(status) {
                        continuation.finish(throwing: SCPError.cancelled)
                    } else {
                        let msg = Self.describeError(
                            exitCode: posixWEXITSTATUS(status),
                            lastOutput: accumulated
                        )
                        continuation.finish(throwing: SCPError.transferFailed(msg))
                    }
                } else {
                    continuation.finish(throwing: SCPError.forkFailed)
                }
            }
        }
    }

    func cancel() {
        let pid = currentPID
        if pid > 0 {
            kill(pid, SIGTERM)
        }
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
        if !trimmed.isEmpty {
            return trimmed
        }
        return "SCP exited with code \(exitCode)."
    }
}
