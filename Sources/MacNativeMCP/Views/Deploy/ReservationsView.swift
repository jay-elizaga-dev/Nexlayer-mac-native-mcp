import SwiftUI
import AppKit


@MainActor
struct ReservationsView: View {
    @Environment(AuthManager.self) private var auth

    @State private var reservations: [Reservation] = []
    @State private var isLoading = false
    @State private var loadError: String?

    @State private var extendingIds: Set<String> = []
    @State private var claimingIds: Set<String> = []
    @State private var removingIds: Set<String> = []
    @State private var claimResults: [String: String] = [:]
    @State private var rowErrors: [String: String] = [:]

    @State private var isRemovingAll = false
    @State private var removeAllError: String?

    private static let baseURL = "https://api.nexlayer.com"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow

            if !auth.isWebSessionLinked {
                sessionRequiredBanner
            } else {
                contentArea
            }
        }
        .task {
            if auth.isWebSessionLinked && reservations.isEmpty {
                await fetchReservations()
            }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            Text("Deployment Reservations")
                .font(AppFonts.label)
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
            if auth.isWebSessionLinked {
                Button {
                    Task { await removeAllReservations() }
                } label: {
                    if isRemovingAll {
                        ProgressView().scaleEffect(0.55)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "trash").font(.system(size: 11))
                            Text("Remove All").font(AppFonts.label)
                        }
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isRemovingAll || reservations.isEmpty)
                .foregroundStyle(AppColors.danger)

                Button {
                    Task { await fetchReservations() }
                } label: {
                    if isLoading {
                        ProgressView().scaleEffect(0.55)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .buttonStyle(.plain)
                .help("Refresh reservations")
            }
        }
    }

    // MARK: - Content area

    @ViewBuilder
    private var contentArea: some View {
        if isLoading && reservations.isEmpty {
            HStack {
                ProgressView()
                Text("Loading reservations…")
                    .font(AppFonts.label)
                    .foregroundStyle(AppColors.textSecondary)
            }
        } else if let error = loadError {
            inlineError(error) { loadError = nil }
        } else if reservations.isEmpty {
            Text("No active reservations")
                .font(AppFonts.label)
                .foregroundStyle(AppColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
        } else {
            VStack(spacing: 8) {
                if let error = removeAllError {
                    inlineError(error) { removeAllError = nil }
                }
                ForEach(reservations) { reservation in
                    reservationRow(reservation)
                }
            }
        }
    }

    // MARK: - Session required banner

    private var sessionRequiredBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "link")
                .font(.system(size: 11))
                .foregroundStyle(AppColors.accent)
            Text("Link your account to view and manage deployment reservations")
                .font(AppFonts.label)
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
            Button("Link Account") {
                auth.openWebSignIn()
            }
            .buttonStyle(.borderedProminent)
            .font(AppFonts.label)
        }
        .padding(10)
        .background(AppColors.accent.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(AppColors.accent.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Reservation row

    @ViewBuilder
    private func reservationRow(_ r: Reservation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(r.applicationName)
                            .font(AppFonts.prose)
                            .foregroundStyle(AppColors.textPrimary)
                        statusBadge(r.status)
                    }
                    Text(r.environment)
                        .font(AppFonts.label)
                        .foregroundStyle(AppColors.textSecondary)
                    Text(r.url)
                        .font(AppFonts.codeSmall)
                        .foregroundStyle(AppColors.accent)
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    dateLabel("Created", r.createdAt)
                    dateLabel("Expires", r.expiresAt)
                }
            }

            HStack(spacing: 6) {
                rowButton("Extend", icon: "clock.arrow.circlepath",
                          loading: extendingIds.contains(r.applicationName)) {
                    Task { await extendDeployment(r) }
                }
                rowButton("Claim", icon: "square.and.arrow.down",
                          loading: claimingIds.contains(r.applicationName)) {
                    Task { await claimDeployment(r) }
                }
                Spacer()
                rowButton("Remove", icon: "trash",
                          loading: removingIds.contains(r.applicationName),
                          role: .destructive) {
                    Task { await removeReservation(r) }
                }
            }

            if let claimURL = claimResults[r.applicationName] {
                claimURLBanner(claimURL, appName: r.applicationName)
            }

            if let error = rowErrors[r.applicationName] {
                inlineError(error) { rowErrors[r.applicationName] = nil }
            }
        }
        .padding(12)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColors.border, lineWidth: 1))
    }

    // MARK: - Sub-components

    @ViewBuilder
    private func statusBadge(_ status: String) -> some View {
        let color: Color = {
            switch status.lowercased() {
            case "active":           return AppColors.success
            case "pending":          return AppColors.warning
            case "expired", "failed": return AppColors.danger
            default:                 return AppColors.textSecondary
            }
        }()
        Text(status)
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.5)
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func dateLabel(_ prefix: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text("\(prefix):")
                .font(AppFonts.label)
                .foregroundStyle(AppColors.textSecondary)
            Text(formattedDate(value))
                .font(AppFonts.label)
                .foregroundStyle(AppColors.textPrimary)
        }
    }

    @ViewBuilder
    private func rowButton(
        _ label: String,
        icon: String,
        loading: Bool,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            if loading {
                ProgressView().scaleEffect(0.55).frame(width: 64)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: icon).font(.system(size: 10))
                    Text(label).font(AppFonts.label)
                }
            }
        }
        .buttonStyle(.bordered)
        .disabled(loading)
    }

    @ViewBuilder
    private func claimURLBanner(_ url: String, appName: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppColors.success)
            Text(url)
                .font(AppFonts.codeSmall)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url, forType: .string)
            }
            .buttonStyle(.bordered)
            .font(AppFonts.label)
            Button {
                claimResults[appName] = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(AppColors.success.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private func inlineError(_ message: String, onDismiss: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(AppColors.danger)
            Text(message)
                .font(AppFonts.label)
                .foregroundStyle(AppColors.danger)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(AppColors.danger.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Date formatting

    private func formattedDate(_ raw: String) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = iso.date(from: raw)
        if date == nil {
            iso.formatOptions = [.withInternetDateTime]
            date = iso.date(from: raw)
        }
        guard let date else { return raw }
        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .short
        return display.string(from: date)
    }

    // MARK: - API

    private func fetchReservations() async {
        guard let token = auth.webSessionToken else { return }
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            var components = URLComponents(string: "\(Self.baseURL)/getReservations")!
            components.queryItems = [URLQueryItem(name: "sessionToken", value: token)]
            let (data, response) = try await URLSession.shared.data(from: components.url!)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                loadError = "Server error \(http.statusCode)"
                return
            }
            let decoded = try JSONDecoder().decode(ReservationsResponse.self, from: data)
            reservations = decoded.reservations
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func extendDeployment(_ r: Reservation) async {
        guard let token = auth.webSessionToken else { return }
        extendingIds.insert(r.applicationName)
        rowErrors[r.applicationName] = nil
        defer { extendingIds.remove(r.applicationName) }
        do {
            try await post("/extendDeployment", body: ["applicationName": r.applicationName,
                                                       "sessionToken": token])
        } catch {
            rowErrors[r.applicationName] = "Extend failed: \(error.localizedDescription)"
        }
    }

    private func claimDeployment(_ r: Reservation) async {
        guard let token = auth.webSessionToken else { return }
        claimingIds.insert(r.applicationName)
        rowErrors[r.applicationName] = nil
        claimResults[r.applicationName] = nil
        defer { claimingIds.remove(r.applicationName) }
        do {
            let data = try await post("/claimDeployment", body: ["applicationName": r.applicationName,
                                                                  "sessionToken": token])
            if let decoded = try? JSONDecoder().decode(ClaimResponse.self, from: data) {
                claimResults[r.applicationName] = decoded.claimUrl
            }
        } catch {
            rowErrors[r.applicationName] = "Claim failed: \(error.localizedDescription)"
        }
    }

    private func removeReservation(_ r: Reservation) async {
        guard let token = auth.webSessionToken else { return }
        removingIds.insert(r.applicationName)
        rowErrors[r.applicationName] = nil
        defer { removingIds.remove(r.applicationName) }
        do {
            try await post("/removeDeploymentReservation", body: ["applicationName": r.applicationName,
                                                                   "sessionToken": token])
            reservations.removeAll { $0.applicationName == r.applicationName }
        } catch {
            rowErrors[r.applicationName] = "Remove failed: \(error.localizedDescription)"
        }
    }

    private func removeAllReservations() async {
        guard let token = auth.webSessionToken else { return }
        isRemovingAll = true
        removeAllError = nil
        defer { isRemovingAll = false }
        do {
            try await post("/removeReservations", body: ["sessionToken": token])
            reservations = []
        } catch {
            removeAllError = "Remove all failed: \(error.localizedDescription)"
        }
    }

    @discardableResult
    private func post(_ path: String, body: [String: String]) async throws -> Data {
        var request = URLRequest(url: URL(string: "\(Self.baseURL)\(path)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let msg = String(data: data, encoding: .utf8) ?? "Server error \(http.statusCode)"
            throw URLError(.badServerResponse,
                           userInfo: [NSLocalizedDescriptionKey: msg])
        }
        return data
    }
}

// MARK: - Models

private struct Reservation: Identifiable, Decodable {
    var id: String { applicationName }
    let applicationName: String
    let environment: String
    let url: String
    let status: String
    let createdAt: String
    let expiresAt: String
}

private struct ReservationsResponse: Decodable {
    let reservations: [Reservation]
}

private struct ClaimResponse: Decodable {
    let claimUrl: String
}
