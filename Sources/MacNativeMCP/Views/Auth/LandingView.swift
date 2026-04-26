import SwiftUI

struct LandingView: View {
    @Environment(AuthManager.self) private var auth
    @State private var apiKey: String = ""
    @FocusState private var keyFieldFocused: Bool

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo mark
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(AppColors.surface)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.border, lineWidth: 1))
                        .frame(width: 80, height: 80)
                    Image(systemName: "network")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(AppColors.accent)
                }

                Spacer().frame(height: 28)

                Text("Mac Native MCP")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)

                Spacer().frame(height: 8)

                Text("Log in to Nexlayer via MCP")
                    .font(AppFonts.prose)
                    .foregroundStyle(AppColors.textSecondary)

                Spacer().frame(height: 40)

                switch auth.state {
                case .checking, .connecting:
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(auth.state == .checking ? "Checking saved session…" : "Connecting to Nexlayer…")
                            .font(AppFonts.label)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                case .unauthenticated, .error:
                    VStack(spacing: 16) {
                        // Error banner
                        if case .error(let msg) = auth.state {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(AppColors.danger)
                                Text(msg)
                                    .font(AppFonts.label)
                                    .foregroundStyle(AppColors.danger)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(10)
                            .background(AppColors.danger.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .frame(maxWidth: 320)
                        }

                        // API key input
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text("API KEY")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(AppColors.textSecondary)
                                    .tracking(1)
                                Button("Get one →") {
                                    NSWorkspace.shared.open(URL(string: "https://app.nexlayer.com/settings/api-keys")!)
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(AppColors.accent)
                                .tracking(1)
                            }

                            SecureField("Paste your Nexlayer API key…", text: $apiKey)
                                .textFieldStyle(.plain)
                                .font(AppFonts.code)
                                .foregroundStyle(AppColors.textPrimary)
                                .focused($keyFieldFocused)
                                .onSubmit { submit() }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(AppColors.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(keyFieldFocused ? AppColors.accent : AppColors.border, lineWidth: 1)
                                )
                                .frame(width: 320)

                            Text("app.nexlayer.com/settings/api-keys")
                                .font(.system(size: 10))
                                .foregroundStyle(AppColors.textSecondary.opacity(0.6))
                        }

                        // Connect button
                        Button(action: submit) {
                            Text("Connect")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 320, height: 44)
                                .background(apiKey.isEmpty ? AppColors.border : AppColors.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .disabled(apiKey.isEmpty)
                    }

                case .authenticated:
                    EmptyView()
                }

                Spacer()

                Text("Powered by nexlayer.com · elizaga.dev")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.border)
                    .padding(.bottom, 24)
            }
        }
        .onAppear {
            keyFieldFocused = true
            // Pre-fill from stored key or dev env (user still must press Connect)
            if apiKey.isEmpty {
                if let devKey = auth.devEnvKey {
                    apiKey = devKey
                } else if let stored = auth.storedKey {
                    apiKey = stored
                }
            }
        }
    }

    private func submit() {
        guard !apiKey.isEmpty else { return }
        Task { await auth.authenticate(apiKey: apiKey) }
    }
}
