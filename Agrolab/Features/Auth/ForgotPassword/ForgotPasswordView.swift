//
//  ForgotPasswordView.swift
//  Agrolab
//

import SwiftUI

struct ForgotPasswordView: View {
    @Environment(AuthRouter.self) private var router
    @State private var viewModel: ForgotPasswordViewModel
    @FocusState private var focusedField: Field?

    private enum Field { case email, token, password, confirm }

    init(viewModel: ForgotPasswordViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            AuthHeader(subtitle: "Vamos recuperar seu acesso") {
                router.pop()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch viewModel.step {
                    case .requestEmail:
                        requestStep
                    case .resetPassword:
                        resetStep
                    case .done:
                        doneStep
                    }
                }
                .padding(.horizontal, AgroTheme.Spacing.screen)
                .padding(.top, 32)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(AgroTheme.Colors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .animation(.easeOut(duration: 0.25), value: viewModel.step)
        .animation(.easeOut(duration: 0.2), value: viewModel.errorMessage)
        .sensoryFeedback(.error, trigger: viewModel.errorMessage) { _, new in new != nil }
        .sensoryFeedback(.success, trigger: viewModel.step) { _, new in new == .done }
    }

    // MARK: Etapa 1 – e-mail

    @ViewBuilder
    private var requestStep: some View {
        header(
            title: "Esqueci minha senha",
            subtitle: "Informe o e-mail da sua conta e enviaremos um código de recuperação."
        )

        AgroTextField(
            icon: "envelope",
            placeholder: "E-mail",
            text: $viewModel.email,
            keyboard: .emailAddress,
            contentType: .username,
            submitLabel: .send,
            autocapitalization: .never,
            onSubmit: { Task { await viewModel.requestReset() } }
        )
        .focused($focusedField, equals: .email)
        .onChange(of: viewModel.email) { viewModel.clearError() }

        if let error = viewModel.errorMessage {
            InlineMessage(kind: .error, message: error)
        }

        AgroPrimaryButton(title: "Enviar código", isLoading: viewModel.isLoading) {
            focusedField = nil
            Task { await viewModel.requestReset() }
        }
        .disabled(!viewModel.canRequest)
        .padding(.top, 8)

        AgroLinkButton(title: "Já tenho um código") {
            viewModel.skipToReset()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Etapa 2 – token + nova senha

    @ViewBuilder
    private var resetStep: some View {
        header(
            title: "Nova senha",
            subtitle: "Cole o código recebido por e-mail e escolha uma nova senha."
        )

        if let info = viewModel.infoMessage {
            InlineMessage(kind: .info, message: info)
        }

        AgroTextField(
            icon: "key",
            placeholder: "Código de recuperação",
            text: $viewModel.resetToken,
            contentType: .oneTimeCode,
            autocapitalization: .never,
            onSubmit: { focusedField = .password }
        )
        .focused($focusedField, equals: .token)
        .onChange(of: viewModel.resetToken) { viewModel.clearError() }

        AgroTextField(
            icon: "lock.fill",
            placeholder: "Nova senha (mín. 12 caracteres)",
            text: $viewModel.newPassword,
            isSecure: true,
            contentType: .newPassword,
            onSubmit: { focusedField = .confirm }
        )
        .focused($focusedField, equals: .password)

        AgroTextField(
            icon: "lock.rotation",
            placeholder: "Confirmar nova senha",
            text: $viewModel.confirmPassword,
            isSecure: true,
            contentType: .newPassword,
            submitLabel: .done,
            onSubmit: { focusedField = nil }
        )
        .focused($focusedField, equals: .confirm)

        if !viewModel.confirmPassword.isEmpty && !viewModel.passwordsMatch {
            Text("As senhas não coincidem")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AgroTheme.Colors.danger)
                .padding(.leading, 6)
        }

        if let error = viewModel.errorMessage {
            InlineMessage(kind: .error, message: error)
        }

        AgroPrimaryButton(title: "Redefinir senha", isLoading: viewModel.isLoading) {
            focusedField = nil
            Task { await viewModel.reset() }
        }
        .disabled(!viewModel.canReset)
        .padding(.top, 8)
    }

    // MARK: Etapa 3 – concluído

    @ViewBuilder
    private var doneStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(AgroTheme.Colors.primary)
                .padding(.top, 24)

            Text("Senha redefinida")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AgroTheme.Colors.textPrimary)

            Text("Suas sessões anteriores foram encerradas. Entre novamente com a nova senha.")
                .font(.system(size: 17))
                .foregroundStyle(AgroTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            AgroPrimaryButton(title: "Ir para o login") {
                router.showLogin()
            }
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private func header(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AgroTheme.Colors.textPrimary)
            Text(subtitle)
                .font(.system(size: 17))
                .foregroundStyle(AgroTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 8)
    }
}

#Preview {
    let container = AppContainer()
    NavigationStack {
        ForgotPasswordView(viewModel: ForgotPasswordViewModel(authService: container.authService))
    }
    .environment(AuthRouter())
    .environment(container)
}
