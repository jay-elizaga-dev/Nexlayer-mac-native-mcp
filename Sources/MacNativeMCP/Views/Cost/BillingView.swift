import SwiftUI
import AppKit

@MainActor
struct BillingView: View {
    @Environment(NexlayerService.self) var nexlayer
    @Environment(AuthManager.self) var auth

    @State private var couponCode = ""
    @State private var showReferralPopover = false
    @State private var couponResultVisible = false
    @State private var couponResultTask: Task<Void, Never>?

    private var hasSession: Bool { auth.isWebSessionLinked }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            balanceCard

            // Session-required tools — show link-account prompt when no session
            if hasSession {
                actionRow
                referralAndCouponRow
            } else {
                sessionRequiredBanner
                actionRowNoSession
            }

            if couponResultVisible, let result = nexlayer.couponResult,
               !result.hasPrefix("__needs_session__") {
                couponResultBanner(result)
            }
        }
        .task {
            if nexlayer.creditBalance == nil {
                await nexlayer.fetchCredits()
            }
        }
    }

    // MARK: - Balance card

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Account Balance")
                    .font(AppFonts.label)
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
                Button {
                    Task { await nexlayer.fetchCredits() }
                } label: {
                    if nexlayer.isFetchingCredits {
                        ProgressView().scaleEffect(0.55)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .buttonStyle(.plain)
                .help("Refresh balance")
            }

            if nexlayer.isFetchingCredits && nexlayer.creditBalance == nil {
                HStack {
                    ProgressView()
                    Text("Loading…")
                        .font(AppFonts.label)
                        .foregroundStyle(AppColors.textSecondary)
                }
            } else if let bal = nexlayer.creditBalance {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(creditColor(bal.remaining))
                                .frame(width: 7, height: 7)
                            Text("Plan: \(bal.plan)")
                                .font(AppFonts.prose)
                                .foregroundStyle(AppColors.textPrimary)
                        }

                        Text("\(bal.remaining.formatted())")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(creditColor(bal.remaining))
                        + Text(" credits")
                            .font(AppFonts.prose)
                            .foregroundStyle(AppColors.textSecondary)

                        Group {
                            if bal.bonus > 0 {
                                Text("+\(bal.bonus.formatted()) bonus · \(bal.used.formatted()) used")
                            } else {
                                Text("\(bal.used.formatted()) used")
                            }
                        }
                        .font(AppFonts.label)
                        .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer()

                    Text(bal.accessLevel)
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(bal.accessLevel == "full" ? AppColors.success : AppColors.warning)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background((bal.accessLevel == "full" ? AppColors.success : AppColors.warning).opacity(0.12))
                        .clipShape(Capsule())
                }

                if bal.total > 0 {
                    let fraction = min(1.0, Double(bal.used) / Double(bal.total + bal.bonus))
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(AppColors.border)
                                .frame(height: 5)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(creditColor(bal.remaining))
                                .frame(width: geo.size.width * CGFloat(1.0 - fraction), height: 5)
                        }
                    }
                    .frame(height: 5)
                }
            } else {
                Text("Balance unavailable")
                    .font(AppFonts.label)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(12)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColors.border, lineWidth: 1))
    }

    // MARK: - Action row (when session linked)

    private var actionRow: some View {
        HStack(spacing: 8) {
            let upgradeURL = nexlayer.creditBalance?.upgradeURL ?? "https://app.nexlayer.com/settings/plans"

            actionButton(label: "Purchase Credits", icon: "creditcard") {
                NSWorkspace.shared.open(URL(string: upgradeURL)!)
            }
            actionButton(label: "Upgrade Plan", icon: "arrow.up.circle") {
                NSWorkspace.shared.open(URL(string: upgradeURL)!)
            }
            actionButton(label: "Billing Portal", icon: "building.columns") {
                nexlayer.openBillingPortal()
            }
        }
    }

    private var referralAndCouponRow: some View {
        HStack(spacing: 8) {
            // Referral button
            Button {
                if nexlayer.referralLink == nil || nexlayer.referralLink == "__needs_session__" {
                    Task { await nexlayer.fetchReferral() }
                }
                showReferralPopover = true
            } label: {
                HStack(spacing: 5) {
                    if nexlayer.isFetchingReferral {
                        ProgressView().scaleEffect(0.55)
                    } else {
                        Image(systemName: "gift")
                    }
                    Text("Get Referral Link")
                        .font(AppFonts.label)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
            }
            .buttonStyle(.bordered)
            .popover(isPresented: $showReferralPopover, arrowEdge: .bottom) {
                referralPopover
            }

            // Coupon field + Apply
            HStack(spacing: 6) {
                TextField("Coupon code", text: $couponCode)
                    .textFieldStyle(.plain)
                    .font(AppFonts.code)
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(AppColors.inputBg)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppColors.border, lineWidth: 1))
                    .frame(maxWidth: .infinity)
                    .onSubmit { applyCoupon() }

                Button(action: applyCoupon) {
                    if nexlayer.isApplyingCoupon {
                        ProgressView().scaleEffect(0.55).frame(width: 40)
                    } else {
                        Text("Apply").font(AppFonts.label).frame(width: 40)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(couponCode.trimmingCharacters(in: .whitespaces).isEmpty || nexlayer.isApplyingCoupon)
            }
        }
    }

    // MARK: - Action row (when no session — only non-session actions)

    private var actionRowNoSession: some View {
        HStack(spacing: 8) {
            let upgradeURL = nexlayer.creditBalance?.upgradeURL ?? "https://app.nexlayer.com/settings/plans"

            actionButton(label: "Purchase Credits", icon: "creditcard") {
                NSWorkspace.shared.open(URL(string: upgradeURL)!)
            }
            actionButton(label: "Upgrade Plan", icon: "arrow.up.circle") {
                NSWorkspace.shared.open(URL(string: upgradeURL)!)
            }
            actionButton(label: "Billing Portal", icon: "building.columns") {
                nexlayer.openBillingPortal()
            }
        }
    }

    // MARK: - Session required banner

    private var sessionRequiredBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "link")
                .font(.system(size: 11))
                .foregroundStyle(AppColors.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text("Link your account to use referral codes and coupons")
                    .font(AppFonts.label)
                    .foregroundStyle(AppColors.textSecondary)
            }
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

    // MARK: - Referral popover

    private var referralPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Referral Link")
                .font(AppFonts.label)
                .foregroundStyle(AppColors.textSecondary)

            if nexlayer.isFetchingReferral {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Fetching…").font(AppFonts.prose).foregroundStyle(AppColors.textSecondary)
                }
            } else if let link = nexlayer.referralLink, !link.isEmpty, link != "__needs_session__" {
                let isURL = link.hasPrefix("http")
                Text(link)
                    .font(isURL ? AppFonts.code : AppFonts.prose)
                    .foregroundStyle(isURL ? AppColors.textPrimary : AppColors.textSecondary)
                    .lineLimit(4)
                    .textSelection(.enabled)

                if isURL {
                    HStack(spacing: 8) {
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(link, forType: .string)
                            showReferralPopover = false
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Open") {
                            NSWorkspace.shared.open(URL(string: link)!)
                            showReferralPopover = false
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } else {
                Text("No referral link available.")
                    .font(AppFonts.prose)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(14)
        .frame(width: 300)
        .background(AppColors.surface)
    }

    // MARK: - Coupon result banner

    @ViewBuilder
    private func couponResultBanner(_ result: String) -> some View {
        let isError = result.lowercased().contains("error")
        HStack(spacing: 6) {
            Image(systemName: isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle(isError ? AppColors.danger : AppColors.success)
            Text(result)
                .font(AppFonts.label)
                .foregroundStyle(isError ? AppColors.danger : AppColors.success)
                .lineLimit(3)
        }
        .padding(8)
        .background((isError ? AppColors.danger : AppColors.success).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Action button

    @ViewBuilder
    private func actionButton(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11))
                Text(label).font(AppFonts.label).lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
        }
        .buttonStyle(.bordered)
    }

    // MARK: - Helpers

    private func creditColor(_ remaining: Int) -> Color {
        if remaining > 1000 { return AppColors.success }
        if remaining > 0    { return AppColors.warning }
        return AppColors.danger
    }

    private func applyCoupon() {
        let code = couponCode.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else { return }
        couponResultTask?.cancel()
        Task {
            await nexlayer.applyCoupon(code: code)
            if nexlayer.couponResult != "__needs_session__" {
                couponCode = ""
                withAnimation { couponResultVisible = true }
                couponResultTask = Task {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    if !Task.isCancelled {
                        withAnimation { couponResultVisible = false }
                    }
                }
            }
        }
    }
}
