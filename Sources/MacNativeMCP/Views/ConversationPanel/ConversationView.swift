import SwiftUI


struct ConversationView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Conversation").font(AppFonts.heading).foregroundStyle(AppColors.textPrimary)
                Spacer()
            }
            .padding(12)

            Divider().background(AppColors.border)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(appState.messages) { msg in
                            MessageView(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding(12)
                }
                .onChange(of: appState.messages.count) { _, _ in
                    if let last = appState.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            Divider().background(AppColors.border)
            InputBarView()
        }
        .background(AppColors.background)
    }
}
