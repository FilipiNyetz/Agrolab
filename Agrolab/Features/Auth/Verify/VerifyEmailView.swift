//
//  VerifyEmailView.swift
//  Agrolab
//

import SwiftUI

struct VerifyEmailView: View {
    @Environment(AuthRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: VerifyEmailViewModel
    @FocusState private var isCodeFocused: Bool

    init(viewModel: VerifyEmailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            AuthHeader(subtitle: "Falta pouco para começar") {
                router.pop()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirme seu e-mail")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(AgroTheme.Colors.textPrimary)
                        Text("Enviamos um código de 6 dígitos para")
                            .font(.system(size: 17))
                            .foregroundStyle(AgroTheme.Colors.textSecondary)
                        Text(viewModel.email)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AgroTheme.Colors.primaryDark)
                    }
                    .padding(.bottom, 4)

                    CodeInputView(code: $viewModel.code, isFocused: $isCodeFocused, hasError: viewModel.errorMessage != nil)
                        .onChange(of: viewModel.code) { viewModel.sanitizeCode() }

                    HStack(spacing: 8) {
                        Image(systemName: viewModel.isCodeExpired ? "clock.badge.xmark" : "clock")
                        Text(viewModel.expiryText)
                            .monospacedDigit()
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(viewModel.isCodeExpired ? AgroTheme.Colors.danger : AgroTheme.Colors.textSecondary)

                    if let info = viewModel.infoMessage {
                        InlineMessage(kind: .success, message: info)
                    }
                    if let error = viewModel.errorMessage {
                        InlineMessage(kind: .error, message: error)
                    }

                    AgroPrimaryButton(title: "Confirmar", isLoading: viewModel.isVerifying) {
                        isCodeFocused = false
                        Task { await viewModel.verify() }
                    }
                    .disabled(!viewModel.canVerify)
                    .padding(.top, 8)

                    ResendRow(
                        secondsRemaining: viewModel.secondsUntilResend,
                        isResending: viewModel.isResending,
                        canResend: viewModel.canResend
                    ) {
                        Task { await viewModel.resend() }
                    }

                    Text("Não encontrou? Verifique a caixa de spam. O código vale por 60 segundos a partir do envio.")
                        .font(.system(size: 14))
                        .foregroundStyle(AgroTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(.horizontal, AgroTheme.Spacing.screen)
                .padding(.top, 32)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(AgroTheme.Colors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .animation(.easeOut(duration: 0.2), value: viewModel.errorMessage)
        .animation(.easeOut(duration: 0.2), value: viewModel.infoMessage)
        .sensoryFeedback(.error, trigger: viewModel.errorMessage) { _, new in new != nil }
        .task { await viewModel.runClock() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { viewModel.refreshClock() }
        }
        .onAppear { isCodeFocused = true }
    }
}

// MARK: - Subviews

/// Seis caixas de dígitos sobre um TextField invisível (teclado numérico, valor sempre String).
private struct CodeInputView: View {
    @Binding var code: String
    var isFocused: FocusState<Bool>.Binding
    var hasError: Bool

    private let length = VerifyEmailViewModel.codeLength

    var body: some View {
        ZStack {
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused(isFocused)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .accessibilityLabel("Código de verificação")

            HStack(spacing: 10) {
                ForEach(0..<length, id: \.self) { index in
                    digitBox(at: index)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { isFocused.wrappedValue = true }
        }
    }

    private func digitBox(at index: Int) -> some View {
        let characters = Array(code)
        let digit = index < characters.count ? String(characters[index]) : ""
        let isActive = isFocused.wrappedValue && index == min(characters.count, length - 1)
        let borderColor: Color = hasError
            ? AgroTheme.Colors.danger
            : (isActive ? AgroTheme.Colors.primary : AgroTheme.Colors.fieldBorder.opacity(0.6))

        return Text(digit)
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundStyle(AgroTheme.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(AgroTheme.Colors.fieldBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isActive ? 2 : 1.5)
            }
            .animation(.easeOut(duration: 0.15), value: isActive)
    }
}

private struct ResendRow: View {
    let secondsRemaining: Int
    let isResending: Bool
    let canResend: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text("Não recebeu?")
                .foregroundStyle(AgroTheme.Colors.textSecondary)

            if isResending {
                ProgressView().controlSize(.small)
            } else if canResend {
                AgroLinkButton(title: "Reenviar código", action: action)
            } else {
                Text("Reenviar em \(secondsRemaining) s")
                    .monospacedDigit()
                    .foregroundStyle(AgroTheme.Colors.textSecondary)
                    .fontWeight(.semibold)
            }
        }
        .font(.system(size: 17))
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    let container = AppContainer()
    let pending = PendingRegistration(
        registrationToken: "preview",
        email: "produtor@example.com",
        password: "Senha-segura-123!",
        expiresAt: .now.addingTimeInterval(60),
        resendAvailableAt: .now.addingTimeInterval(60)
    )
    NavigationStack {
        VerifyEmailView(
            viewModel: VerifyEmailViewModel(pending: pending, authService: container.authService, session: container.session)
        )
    }
    .environment(AuthRouter())
    .environment(container)
}
