import SwiftUI


@MainActor
struct AddServerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let initial: AppState.ServerConfig?
    let onSave: (AppState.ServerConfig) -> Void

    @State private var name: String
    @State private var command: String
    @State private var arguments: String
    @State private var envVars: [EnvVar]
    @State private var commandError = false

    struct EnvVar: Identifiable {
        var id = UUID()
        var key: String = ""
        var value: String = ""
    }

    init(initial: AppState.ServerConfig? = nil, onSave: @escaping (AppState.ServerConfig) -> Void) {
        self.initial = initial
        self.onSave = onSave
        _name = State(initialValue: initial?.name ?? "")
        _command = State(initialValue: initial?.command ?? "")
        _arguments = State(initialValue: initial?.args.joined(separator: " ") ?? "")
        _envVars = State(initialValue: initial?.envVars.map { EnvVar(key: $0, value: $1) } ?? [])
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(initial == nil ? "Add Server" : "Edit Server")
                    .font(AppFonts.heading)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
            }
            .padding(16)

            Divider().background(AppColors.border)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    field(label: "Name") {
                        TextField("My Server", text: $name)
                            .styledInput()
                    }

                    field(label: "Command") {
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("/usr/bin/npx", text: $command)
                                .font(AppFonts.code)
                                .styledInput(error: commandError)
                            if commandError {
                                Text("Command is required")
                                    .font(AppFonts.label)
                                    .foregroundStyle(AppColors.danger)
                            }
                        }
                    }

                    field(label: "Arguments") {
                        TextField("@modelcontextprotocol/server-filesystem /", text: $arguments)
                            .font(AppFonts.code)
                            .styledInput()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Environment Variables")
                                .font(AppFonts.label)
                                .foregroundStyle(AppColors.textSecondary)
                            Spacer()
                            Button(action: { envVars.append(EnvVar()) }) {
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(AppColors.accent)
                            }
                            .buttonStyle(.plain)
                        }

                        ForEach($envVars) { $envVar in
                            HStack(spacing: 8) {
                                TextField("KEY", text: $envVar.key)
                                    .font(AppFonts.codeSmall)
                                    .styledInput()
                                    .frame(maxWidth: .infinity)
                                Text("=")
                                    .font(AppFonts.code)
                                    .foregroundStyle(AppColors.textSecondary)
                                TextField("value", text: $envVar.value)
                                    .font(AppFonts.codeSmall)
                                    .styledInput()
                                    .frame(maxWidth: .infinity)
                                Button(action: { envVars.removeAll { $0.id == envVar.id } }) {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(AppColors.danger)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
            }

            Divider().background(AppColors.border)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)

                Button("Save") { save() }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(AppColors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(12)
        }
        .background(AppColors.surface)
        .frame(minWidth: 420, minHeight: 300)
    }

    private func save() {
        let trimmed = command.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            commandError = true
            return
        }
        commandError = false
        let args = arguments.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        let env = Dictionary(uniqueKeysWithValues: envVars.compactMap {
            $0.key.isEmpty ? nil : ($0.key, $0.value)
        })
        let config = AppState.ServerConfig(
            id: initial?.id ?? UUID(),
            name: name,
            command: trimmed,
            args: args,
            envVars: env
        )
        onSave(config)
    }

    @ViewBuilder
    private func field<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AppFonts.label)
                .foregroundStyle(AppColors.textSecondary)
            content()
        }
    }
}

private extension View {
    func styledInput(error: Bool = false) -> some View {
        self
            .textFieldStyle(.plain)
            .foregroundStyle(AppColors.textPrimary)
            .padding(8)
            .background(AppColors.background)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(error ? AppColors.danger : Color.clear, lineWidth: 1)
            )
    }
}
