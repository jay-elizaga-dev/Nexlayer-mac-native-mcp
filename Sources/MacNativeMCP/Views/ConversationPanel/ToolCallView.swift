import SwiftUI

struct ToolCall: Identifiable {
    var id: UUID = UUID()
    var name: String
    var arguments: String  // raw JSON string
    var result: String?

    var prettyArguments: String {
        guard
            let data = arguments.data(using: .utf8),
            let obj = try? JSONSerialization.jsonObject(with: data),
            let pretty = try? JSONSerialization.data(withJSONObject: obj, options: .prettyPrinted),
            let str = String(data: pretty, encoding: .utf8)
        else { return arguments }
        return str
    }
}


struct ToolCallView: View {
    let toolCall: ToolCall
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(AppColors.accent)
                    .font(.caption)
                Text(toolCall.name)
                    .font(AppFonts.codeSmall)
                    .foregroundStyle(AppColors.accent)
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppColors.toolCall)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
            }

            if isExpanded {
                Text(toolCall.prettyArguments)
                    .font(AppFonts.codeSmall)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(8)
                    .background(AppColors.toolCall)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                if let result = toolCall.result {
                    Text(result)
                        .font(AppFonts.codeSmall)
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(8)
                        .background(AppColors.toolResult)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
    }
}
