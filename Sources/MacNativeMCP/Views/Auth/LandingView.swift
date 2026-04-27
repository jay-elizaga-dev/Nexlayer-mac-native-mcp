import SwiftUI

@MainActor
struct LandingView: View {
    @Environment(AuthManager.self) private var auth
    @State private var nexlayerKey: String = ""
    @State private var openRouterKey: String = ""
    @FocusState private var focusedField: Field?

    private enum Field { case nexlayer, claude }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo
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

                Text("Connect your API keys to get started")
                    .font(AppFonts.prose)
                    .foregroundStyle(AppColors.textSecondary)

                // Environment badge (internal builds only)
                if AppEnvironment.current.isInternal {
                    HStack(spacing: 4) {
                        Image(systemName: AppEnvironment.current.displayIcon)
                            .font(.system(size: 9))
                        Text(AppEnvironment.current.displayName.uppercased())
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1)
                    }
                    .foregroundStyle(AppColors.warning)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppColors.warning.opacity(0.12))
                    .clipShape(Capsule())
                    .padding(.top, 8)
                }

                Spacer().frame(height: 40)

                switch auth.state {
                case .checking, .connecting:
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(auth.state == .checking ? "Checking saved session…" : "Connecting…")
                            .font(AppFonts.label)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                case .unauthenticated, .error:
                    VStack(spacing: 20) {
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

                        // Nexlayer key (required)
                        keyField(
                            label: "NEXLAYER API KEY",
                            hint: "required",
                            hintColor: AppColors.textSecondary,
                            placeholder: "Paste your Nexlayer API key…",
                            text: $nexlayerKey,
                            field: .nexlayer,
                            linkURL: URL(string: "https://app.nexlayer.com/settings/api-keys")!,
                            linkLabel: "Get one →"
                        )

                        // OpenRouter key (optional)
                        keyField(
                            label: "OPENROUTER API KEY",
                            hint: "optional — enables AI conversation (Claude, GPT, Llama…)",
                            hintColor: AppColors.textSecondary.opacity(0.7),
                            placeholder: "sk-or-v1-… (leave blank to use tools only)",
                            text: $openRouterKey,
                            field: .claude,
                            linkURL: URL(string: "https://openrouter.ai/keys")!,
                            linkLabel: "Get one →"
                        )

                        // Connect button
                        Button(action: submit) {
                            Text("Connect")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 320, height: 44)
                                .background(nexlayerKey.isEmpty ? AppColors.border : AppColors.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .disabled(nexlayerKey.isEmpty)

                        Text("Keys are stored in macOS Keychain — never sent elsewhere.")
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.textSecondary.opacity(0.5))
                            .frame(maxWidth: 320)
                            .multilineTextAlignment(.center)
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
            focusedField = .nexlayer
            if nexlayerKey.isEmpty {
                nexlayerKey = auth.devEnvKey ?? auth.storedKey ?? ""
            }
            if openRouterKey.isEmpty, let stored = auth.storedOpenRouterKey {
                openRouterKey = stored
            }
        }
    }

    // MARK: - Key field builder

    @ViewBuilder
    private func keyField(
        label: String,
        hint: String,
        hintColor: Color,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        linkURL: URL,
        linkLabel: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)
                    .tracking(1)
                Text("·")
                    .foregroundStyle(AppColors.border)
                    .font(.system(size: 10))
                Text(hint)
                    .font(.system(size: 10))
                    .foregroundStyle(hintColor)
                Spacer()
                Button(linkLabel) { NSWorkspace.shared.open(linkURL) }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
                    .tracking(1)
            }
            SecureField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(AppFonts.code)
                .foregroundStyle(AppColors.textPrimary)
                .focused($focusedField, equals: field)
                .onSubmit { submit() }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(focusedField == field ? AppColors.accent : AppColors.border, lineWidth: 1)
                )
                .frame(width: 320)
        }
    }

    // MARK: - Submit

    private func submit() {
        guard !nexlayerKey.isEmpty else { return }
        if !openRouterKey.isEmpty {
            auth.setOpenRouterKey(openRouterKey)
        }
        Task { await auth.authenticate(apiKey: nexlayerKey) }
    }
}
