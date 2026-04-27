import SwiftUI


@MainActor
struct ToolRowView: View {
    @Environment(AppState.self) var appState

    let tool: MCPTool

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wrench")
                .font(.system(size: 11))
                .foregroundStyle(AppColors.textSecondary)
                .frame(width: 14)

            Text(tool.name)
                .font(AppFonts.codeSmall)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)

            Text(tool.description ?? "")
                .font(AppFonts.label)
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
        }
        .padding(.leading, 28)
        .padding(.trailing, 12)
        .padding(.vertical, 6)
        .background(isHovered ? AppColors.surfaceHover : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { appState.selectedTool = tool }
    }
}
