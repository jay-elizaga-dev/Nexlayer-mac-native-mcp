import Foundation

final class StdioTransport: MCPTransport {
    private let process: Process
    private let stdinPipe: Pipe
    private let stdoutPipe: Pipe
    private var buffer = Data()

    init(command: String, args: [String], env: [String: String] = [:]) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: command)
        proc.arguments = args

        var mergedEnv = ProcessInfo.processInfo.environment
        for (key, value) in env {
            mergedEnv[key] = value
        }
        proc.environment = mergedEnv

        let stdin = Pipe()
        let stdout = Pipe()
        proc.standardInput = stdin
        proc.standardOutput = stdout

        self.process = proc
        self.stdinPipe = stdin
        self.stdoutPipe = stdout
    }

    func start() throws {
        try process.run()
    }

    func send(_ data: Data) async throws {
        var payload = data
        payload.append(0x0A) // newline delimiter
        try stdinPipe.fileHandleForWriting.write(contentsOf: payload)
    }

    func receive() async throws -> Data {
        let newline: UInt8 = 0x0A

        while true {
            // Check if we already have a complete line in the buffer.
            if let newlineIndex = buffer.firstIndex(of: newline) {
                let line = buffer[buffer.startIndex..<newlineIndex]
                buffer = buffer[buffer.index(after: newlineIndex)...]
                return Data(line)
            }

            // Read more data from the process.
            let chunk = stdoutPipe.fileHandleForReading.availableData
            if chunk.isEmpty {
                // availableData returns empty when the pipe's write-end is closed
                // (i.e. the child process has exited).
                if !buffer.isEmpty {
                    // Return whatever is left even without a trailing newline.
                    let remaining = buffer
                    buffer = Data()
                    return remaining
                }
                throw StdioTransportError.processTerminated(
                    "MCP server process terminated before a complete JSON line was received."
                )
            }

            buffer.append(chunk)
        }
    }

    func close() {
        process.terminate()
    }
}

enum StdioTransportError: Error, LocalizedError {
    case processTerminated(String)

    var errorDescription: String? {
        switch self {
        case .processTerminated(let message):
            return message
        }
    }
}
