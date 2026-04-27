import SwiftUI

@MainActor
struct CostDetailView: View {
    let deployment: String
    @Environment(NexlayerService.self) var nexlayer

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(AppColors.border)
            recordList
        }
        .background(AppColors.surface)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(deployment.isEmpty ? "Global Calls" : deployment)
                    .font(AppFonts.heading)
                    .foregroundStyle(AppColors.textPrimary)
                Text("\(records.count) call\(records.count == 1 ? "" : "s")")
                    .font(AppFonts.label)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var recordList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(records) { record in
                    recordRow(record)
                    Divider().background(AppColors.border.opacity(0.5))
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func recordRow(_ r: NexlayerService.ToolCallRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(r.success ? AppColors.success : AppColors.danger)
                    .frame(width: 7, height: 7)
                Text(r.tool)
                    .font(AppFonts.code)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text("\(r.durationMs) ms")
                    .font(AppFonts.label)
                    .foregroundStyle(AppColors.textSecondary)
            }
            HStack {
                Text(formatted(r.timestamp))
                    .font(AppFonts.label)
                    .foregroundStyle(AppColors.textSecondary)
                if let err = r.error {
                    Spacer()
                    Text(err)
                        .font(AppFonts.label)
                        .foregroundStyle(AppColors.danger)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var records: [NexlayerService.ToolCallRecord] {
        nexlayer.callHistory
            .filter { $0.deployment == deployment }
            .sorted { $0.timestamp > $1.timestamp }
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .medium
        return f.string(from: date)
    }
}
