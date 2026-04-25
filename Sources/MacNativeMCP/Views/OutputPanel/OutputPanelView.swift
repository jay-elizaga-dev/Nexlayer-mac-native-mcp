import SwiftUI

struct OutputPanelView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Output").font(AppFonts.heading).foregroundStyle(AppColors.textPrimary)
                Spacer()
                if let tool = appState.lastCalledTool {
                    Text(tool).font(AppFonts.label).foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding(12)

            Divider().background(AppColors.border)

            // Content area — switches based on last tool result type
            if let result = appState.lastToolResult {
                switch result {
                case .code(let content, let lang):
                    CodeBlockView(content: content, language: lang)
                case .fileTree(let entries):
                    FileTreeView(entries: entries)
                case .text(let content):
                    ScrollView {
                        Text(content)
                            .font(AppFonts.prose)
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                // Empty state
                VStack {
                    Spacer()
                    Image(systemName: "terminal")
                        .font(.system(size: 32))
                        .foregroundStyle(AppColors.border)
                    Text("Tool output appears here")
                        .font(AppFonts.prose)
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                }
            }
        }
        .background(AppColors.surface)
    }
}
