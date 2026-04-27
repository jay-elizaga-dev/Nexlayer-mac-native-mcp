import SwiftUI


@MainActor
struct MessageView: View {
    let message: AppState.ConversationMessage

    private var isUser: Bool { message.role == "user" }
    private var roleLabel: String { isUser ? "You" : "Assistant" }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 48) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(roleLabel)
                    .font(AppFonts.label)
                    .foregroundStyle(AppColors.textSecondary)

                Text(message.content)
                    .font(AppFonts.prose)
                    .foregroundStyle(isUser ? AppColors.textPrimary : AppColors.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isUser ? AppColors.accent.opacity(0.15) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if !isUser { Spacer(minLength: 48) }
        }
    }
}
