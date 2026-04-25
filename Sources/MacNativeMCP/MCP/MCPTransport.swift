import Foundation

protocol MCPTransport: AnyObject {
    /// Send raw data to the MCP server process.
    func send(_ data: Data) async throws

    /// Read the next newline-terminated JSON line from the server.
    func receive() async throws -> Data

    /// Terminate the underlying transport connection.
    func close()
}
