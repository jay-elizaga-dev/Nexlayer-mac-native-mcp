import SwiftUI

struct ServerChatView: View {
    @Environment(AppState.self) private var appState
    @Environment(NexlayerService.self) private var nexlayer
    @Environment(AuthManager.self) private var auth

    let chatId: UUID
    let server: AppState.ServerConfig

    @State private var inputText: String = ""
    @State private var editorHeight: CGFloat = 40
    @State private var isSending: Bool = false
    @State private var selectedModel: String = OpenRouterClient.defaultModel

    private let openRouter = OpenRouterClient()

    private var session: AppState.ChatSession? {
        appState.chatSessions.first(where: { $0.id == chatId })
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(AppColors.border)
            messageList
            Divider().background(AppColors.border)
            inputBar
        }
        .background(AppColors.background)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(session?.title ?? "\(server.name): Chat")
                    .font(AppFonts.heading)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Circle()
                        .fill(nexlayer.client != nil ? AppColors.success : AppColors.textSecondary)
                        .frame(width: 6, height: 6)
                    Text(nexlayer.client != nil
                         ? "Nexlayer MCP · \(server.nexlayerApp)"
                         : "Not connected")
                        .font(AppFonts.label)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            Spacer()

            // New chat for same server
            Button {
                appState.createChat(for: server)
            } label: {
                Image(systemName: "plus.bubble")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .buttonStyle(.plain)
            .help("New chat for \(server.name)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if let msgs = session?.messages, !msgs.isEmpty {
                        ForEach(msgs) { msg in
                            MessageView(message: msg).id(msg.id)
                        }
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 28))
                                .foregroundStyle(AppColors.border)
                            Text("Send a command for \(server.name)")
                                .font(AppFonts.prose)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                    }
                }
                .padding(12)
            }
            .onChange(of: session?.messages.count ?? 0) { _, _ in
                if let last = session?.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppColors.border, lineWidth: 1)
                    )

                if inputText.isEmpty {
                    Text("Command for \(server.name)… (⌘↩ to send)")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.top, 11)
                        .allowsHitTesting(false)
                }

                GrowingTextEditor(
                    text: $inputText,
                    height: $editorHeight,
                    onSend: sendMessage
                )
                .padding(.horizontal, 2)
            }
            .frame(height: editorHeight)
            .animation(.easeInOut(duration: 0.1), value: editorHeight)

            Button(action: sendMessage) {
                ZStack {
                    if isSending {
                        ProgressView().scaleEffect(0.75).frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(canSend ? AppColors.accent : AppColors.textSecondary)
                    }
                }
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(canSend ? AppColors.surface : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(canSend ? AppColors.border : Color.clear, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .padding(.bottom, (editorHeight - 32) / 2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppColors.background)
    }

    // MARK: - Send

    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        appState.appendMessage(
            AppState.ConversationMessage(role: "user", content: trimmed),
            toChatId: chatId
        )
        inputText = ""
        editorHeight = 40
        isSending = true

        guard let key = auth.openRouterKey, !key.isEmpty else {
            appState.appendMessage(
                AppState.ConversationMessage(
                    role: "assistant",
                    content: "⚠ OpenRouter key not set — add it in Settings to enable conversation. (Tool calls via Nexlayer still work.)"
                ),
                toChatId: chatId
            )
            isSending = false
            return
        }

        // Build message history for the request
        let history = session?.messages.map {
            OpenRouterClient.Message(role: $0.role, content: $0.content)
        } ?? []

        let systemPrompt = """
        You are a helpful assistant with access to the Nexlayer MCP server "\(server.name)".
        The user may ask you to run Nexlayer tools (deployments, logs, status checks, etc.).
        When you need to use a tool, describe what you would call and the user can trigger it directly.
        Keep responses concise and actionable.
        """

        Task {
            do {
                let (text, _) = try await openRouter.chat(
                    messages: history,
                    model: selectedModel,
                    apiKey: key,
                    systemPrompt: systemPrompt
                )
                appState.appendMessage(
                    AppState.ConversationMessage(role: "assistant", content: text),
                    toChatId: chatId
                )
            } catch {
                appState.appendMessage(
                    AppState.ConversationMessage(role: "assistant", content: "⚠ \(error.localizedDescription)"),
                    toChatId: chatId
                )
            }
            isSending = false
        }
    }
}
