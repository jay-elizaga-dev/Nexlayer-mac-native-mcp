import SwiftUI
import AppKit

// MARK: - InputBarView

struct InputBarView: View {
    @Environment(AppState.self) private var appState

    @State private var inputText: String = ""
    @State private var editorHeight: CGFloat = 40
    // AppState has no isThinking property yet; track locally until it's added.
    @State private var isSending: Bool = false

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Text input area
            ZStack(alignment: .topLeading) {
                // Background + border
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppColors.border, lineWidth: 1)
                    )

                // Placeholder
                if inputText.isEmpty {
                    Text("Message… (⌘↩ to send)")
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

            // Send / spinner button
            Button(action: sendMessage) {
                ZStack {
                    if isSending {
                        ProgressView()
                            .scaleEffect(0.75)
                            .frame(width: 20, height: 20)
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
            .padding(.bottom, (editorHeight - 32) / 2) // align to bottom of input
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppColors.background)
    }

    // MARK: Send

    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        appState.messages.append(
            AppState.ConversationMessage(role: "user", content: trimmed)
        )
        inputText = ""
        editorHeight = 40
        isSending = true
        // Reset isSending once a real response arrives; for now use a short delay.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isSending = false
        }
    }
}
