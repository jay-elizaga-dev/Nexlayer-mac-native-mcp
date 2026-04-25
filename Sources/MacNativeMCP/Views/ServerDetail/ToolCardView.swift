import SwiftUI

struct ToolCardView: View {
    let tool: MCPTool
    let serverId: UUID

    @Environment(AppState.self) private var appState
    @Environment(MCPServerManager.self) private var serverManager

    @State private var isLoading = false
    @State private var isHovered = false

    var body: some View {
        Button(action: callTool) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "wrench")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.accent)

                    Text(tool.name)
                        .font(AppFonts.codeSmall)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    if isLoading {
                        ProgressView().scaleEffect(0.55)
                    }
                }

                if let desc = tool.description, !desc.isEmpty {
                    Text(desc)
                        .font(AppFonts.label)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Arg count
                let argCount = argCount(from: tool.inputSchema)
                if argCount > 0 {
                    Text("\(argCount) param\(argCount == 1 ? "" : "s")")
                        .font(.system(size: 10))
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(AppColors.border)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHovered ? AppColors.surfaceHover : AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(appState.selectedTool?.name == tool.name
                            ? AppColors.accent : AppColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private func callTool() {
        guard !isLoading else { return }
        appState.selectedTool = tool
        appState.lastCalledTool = tool.name
        appState.lastToolResult = nil

        isLoading = true
        Task {
            defer { isLoading = false }
            guard let client = serverManager.clients[serverId] else { return }
            do {
                let result = try await client.callTool(name: tool.name, arguments: [:])
                let text = result.content.compactMap { $0.text }.joined(separator: "\n")
                let lang = detectLanguage(text)
                await MainActor.run {
                    if lang == "json" || lang == "swift" {
                        appState.lastToolResult = .code(text, lang)
                    } else {
                        appState.lastToolResult = .text(text)
                    }
                }
            } catch {
                await MainActor.run {
                    appState.lastToolResult = .text("Error: \(error.localizedDescription)")
                }
            }
        }
    }

    private func argCount(from schema: AnyCodable?) -> Int {
        guard
            let schema,
            let dict = schema.value as? [String: Any],
            let props = dict["properties"] as? [String: Any]
        else { return 0 }
        return props.count
    }

    private func detectLanguage(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") { return "json" }
        if trimmed.hasPrefix("import ") || trimmed.contains("func ") { return "swift" }
        return "text"
    }
}
