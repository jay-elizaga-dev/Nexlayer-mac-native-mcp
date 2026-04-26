import Foundation

/// OpenRouter API client — OpenAI-compatible chat completions endpoint.
///
/// OpenRouter routes to 200+ models (Claude, GPT, Mistral, Llama, Gemini, etc.)
/// using a single API key format. Free tier available.
///
/// Docs: https://openrouter.ai/docs
/// Get key: https://openrouter.ai/keys
@MainActor
final class OpenRouterClient {

    // MARK: - Configuration

    nonisolated static let defaultModel = "anthropic/claude-sonnet-4-5"
    nonisolated static let endpoint = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
    nonisolated static let appURL   = "https://nexlayer-mac-native-mcp.elizaga.dev"
    nonisolated static let appTitle = "Mac Native MCP"

    struct Message: Codable {
        var role: String    // "system" | "user" | "assistant"
        var content: String
    }

    struct CompletionResponse: Decodable {
        struct Choice: Decodable {
            struct MessageContent: Decodable { var content: String }
            var message: MessageContent
            var finish_reason: String?
        }
        struct Usage: Decodable {
            var prompt_tokens: Int
            var completion_tokens: Int
            var total_tokens: Int
        }
        var choices: [Choice]
        var usage: Usage?
        var model: String?
    }

    // MARK: - Errors

    enum ClientError: Error, LocalizedError {
        case noAPIKey
        case httpError(Int, String)
        case decodingError(String)

        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                return "OpenRouter API key not set — add it in Settings."
            case .httpError(let code, let body):
                return "OpenRouter error \(code): \(body)"
            case .decodingError(let msg):
                return "Response decode error: \(msg)"
            }
        }
    }

    // MARK: - Chat

    /// Sends a chat completion request. Returns the assistant's text response.
    func chat(
        messages: [Message],
        model: String = defaultModel,
        apiKey: String,
        systemPrompt: String? = nil
    ) async throws -> (text: String, tokensUsed: Int) {
        var allMessages = messages
        if let sys = systemPrompt {
            allMessages.insert(Message(role: "system", content: sys), at: 0)
        }

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // OpenRouter recommended headers
        request.setValue(Self.appURL,   forHTTPHeaderField: "HTTP-Referer")
        request.setValue(Self.appTitle, forHTTPHeaderField: "X-Title")

        let body: [String: Any] = [
            "model":    model,
            "messages": allMessages.map { ["role": $0.role, "content": $0.content] }
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            throw ClientError.httpError(http.statusCode, body)
        }

        guard let decoded = try? JSONDecoder().decode(CompletionResponse.self, from: data),
              let text = decoded.choices.first?.message.content else {
            throw ClientError.decodingError(String(data: data, encoding: .utf8) ?? "empty")
        }

        return (text: text, tokensUsed: decoded.usage?.total_tokens ?? 0)
    }
}
