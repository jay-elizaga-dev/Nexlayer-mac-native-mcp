import SwiftUI


@MainActor
struct ConversationPanel: View {
    var body: some View {
        ZStack {
            AppColors.background
            Text("Conversation")
                .foregroundStyle(AppColors.textSecondary)
        }
    }
}
