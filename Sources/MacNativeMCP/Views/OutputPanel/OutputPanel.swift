import SwiftUI


@MainActor
struct OutputPanel: View {
    var body: some View {
        ZStack {
            AppColors.surface
            Text("Output")
                .foregroundStyle(AppColors.textSecondary)
        }
    }
}
