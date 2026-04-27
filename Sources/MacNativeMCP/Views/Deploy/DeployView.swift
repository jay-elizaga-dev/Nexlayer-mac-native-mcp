import SwiftUI

@MainActor
struct DeployView: View {
    @State private var yamlContent: String = "# nexlayer.yaml\n"
    @State private var isValidating = false
    @State private var isDeploying = false
    @State private var validationState: ValidationState? = nil
    @State private var deployState: DeployState? = nil

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().background(AppColors.border)
            editorSection
            Divider().background(AppColors.border)
            controlsSection
        }
        .background(AppColors.background)
    }

    // MARK: - Subviews

    private var headerBar: some View {
        HStack {
            Text("Deploy nexlayer.yaml")
                .font(AppFonts.heading)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppColors.panelHeaderBg)
    }

    private var editorSection: some View {
        TextEditor(text: $yamlContent)
            .font(AppFonts.code)
            .foregroundColor(AppColors.textPrimary)
            .scrollContentBackground(.hidden)
            .background(AppColors.inputBg)
            .padding(12)
            .frame(maxHeight: .infinity)
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                validateButton
                deployButton
                Spacer()
            }
            if let vs = validationState {
                statusRow(
                    isSuccess: vs.isSuccess,
                    label: vs.message
                )
            }
            if let ds = deployState {
                VStack(alignment: .leading, spacing: 4) {
                    statusRow(isSuccess: ds.isSuccess, label: ds.status)
                    if let urlString = ds.url, let url = URL(string: urlString) {
                        Link(destination: url) {
                            Text(urlString)
                                .font(AppFonts.codeSmall)
                                .foregroundColor(AppColors.accent)
                                .lineLimit(2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(AppColors.surface)
    }

    private var validateButton: some View {
        Button(action: validate) {
            HStack(spacing: 6) {
                if isValidating {
                    ProgressView()
                        .controlSize(.small)
                        .tint(AppColors.textPrimary)
                }
                Text(isValidating ? "Validating…" : "Validate")
                    .font(AppFonts.label)
                    .foregroundColor(AppColors.textPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(AppColors.surfaceHover)
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppColors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(isBusy || yamlContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private var deployButton: some View {
        Button(action: deploy) {
            HStack(spacing: 6) {
                if isDeploying {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                }
                Text(isDeploying ? "Deploying…" : "Deploy")
                    .font(AppFonts.label)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isDeploying ? AppColors.accentHover : AppColors.accent)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .disabled(isBusy || yamlContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func statusRow(isSuccess: Bool, label: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isSuccess ? AppColors.success : AppColors.danger)
            Text(label)
                .font(AppFonts.label)
                .foregroundColor(isSuccess ? AppColors.success : AppColors.danger)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var isBusy: Bool { isValidating || isDeploying }

    // MARK: - Actions

    private func validate() {
        guard !isBusy else { return }
        isValidating = true
        validationState = nil

        Task {
            defer { isValidating = false }
            do {
                let body = try JSONSerialization.data(withJSONObject: ["yaml": yamlContent])
                var req = URLRequest(url: URL(string: "https://api.nexlayer.com/validate")!)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = body

                let (data, response) = try await URLSession.shared.data(for: req)
                let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? 0
                let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
                let message = json["message"] as? String
                    ?? json["error"] as? String
                    ?? (httpStatus == 200 ? "YAML is valid" : "Validation failed (HTTP \(httpStatus))")
                validationState = ValidationState(isSuccess: httpStatus == 200, message: message)
            } catch {
                validationState = ValidationState(isSuccess: false, message: error.localizedDescription)
            }
        }
    }

    private func deploy() {
        guard !isBusy else { return }
        isDeploying = true
        deployState = nil

        Task {
            defer { isDeploying = false }
            do {
                guard let bodyData = yamlContent.data(using: .utf8) else {
                    deployState = DeployState(isSuccess: false, status: "Failed to encode YAML as UTF-8", url: nil)
                    return
                }
                var req = URLRequest(url: URL(string: "https://api.nexlayer.com/startUserDeployment")!)
                req.httpMethod = "POST"
                req.setValue("text/x-yaml", forHTTPHeaderField: "Content-Type")
                req.httpBody = bodyData

                let (data, response) = try await URLSession.shared.data(for: req)
                let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? 0
                let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
                let status = json["status"] as? String
                    ?? json["message"] as? String
                    ?? json["error"] as? String
                    ?? (httpStatus == 200 ? "Deployed successfully" : "Deployment failed (HTTP \(httpStatus))")
                let url = json["url"] as? String ?? json["deploymentUrl"] as? String
                deployState = DeployState(isSuccess: httpStatus == 200, status: status, url: url)
            } catch {
                deployState = DeployState(isSuccess: false, status: error.localizedDescription, url: nil)
            }
        }
    }
}

// MARK: - State models

private struct ValidationState {
    let isSuccess: Bool
    let message: String
}

private struct DeployState {
    let isSuccess: Bool
    let status: String
    let url: String?
}
