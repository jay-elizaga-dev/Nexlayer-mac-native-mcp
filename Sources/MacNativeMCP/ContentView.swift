import SwiftUI

struct ContentView: View {
    var body: some View {
        HSplitView {
            ServersPanelView()
                .frame(minWidth: 220, maxWidth: 260)

            ConversationView()
                .frame(minWidth: 400)

            OutputPanelView()
                .frame(minWidth: 280)
        }
        .background(AppColors.background)
    }
}
