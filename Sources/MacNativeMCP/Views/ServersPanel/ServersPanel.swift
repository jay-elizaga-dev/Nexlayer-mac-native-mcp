import SwiftUI


struct ServersPanel: View {
    var body: some View {
        ZStack {
            AppColors.surface
            Text("Servers")
                .foregroundStyle(AppColors.textSecondary)
        }
    }
}
