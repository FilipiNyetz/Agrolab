//
//  ChangePasswordView.swift
//  Agrolab
//

import SwiftUI

/// Troca de senha para quem já está logado. A API não tem rota de troca com a senha atual,
/// então o fluxo reutiliza a recuperação: código por e-mail + nova senha. Ao concluir,
/// o servidor revoga as sessões e o app faz logout local.
struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionManager.self) private var session
    @State private var viewModel: ForgotPasswordViewModel
    @FocusState private var focusedField: Field?

    private let email: String
    private enum Field { case token, password, confirm }

    init(email: String, viewModel: ForgotPasswordViewModel) {
        self.email = email
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch viewModel.step {
                    case .requestEmail:
                        sendingStep
                    case .resetPassword:
                        resetStep
                    case .done:
                        doneStep
                    }
                }
                .padding(AgroTheme.Spacing.screen)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AgroTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Alterar senha")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.step != .done {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { dismiss() }
                    }
                }
            }
        }
        .tint(AgroTheme.Colors.primaryDark)
        .interactiveDismissDisabled(viewModel.step == .done)
        .animation(.easeOut(duration: 0.25), value: viewModel.step)
        .animation(.easeOut(duration: 0.2), value: viewModel.errorMessage)
        .task {
            guard viewModel.step == .requestEmail else { return }
            viewModel.email = email
            await viewModel.requestReset()
        }
    }

    @ViewBuilder
    private var sendingStep: some View {
        if viewModel.isLoading {
            HStack(spacing: 12) {
                ProgressView()
                Text("Enviando código para \(email)…")
                    .foregroundStyle(AgroTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 32)
        } else if let error = viewModel.errorMessage {
            InlineMessage(kind: .error, message: error)
            AgroPrimaryButton(title: "Tentar novamente") {
                Task { await viewModel.requestReset() }
            }
        }
    }

    @ViewBuilder
    private var resetStep: some View {
        Text("Enviamos um código de recuperação para **\(email)**. Cole o código e escolha a nova senha.")
            .font(.system(size: 16))
            .foregroundStyle(AgroTheme.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)

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

    @ViewBuilder
    private var doneStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(AgroTheme.Colors.primary)
                .padding(.top, 24)
            Text("Senha alterada")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(AgroTheme.Colors.textPrimary)
            Text("Por segurança, todas as sessões foram encerradas. Entre novamente com a nova senha.")
                .font(.system(size: 16))
                .foregroundStyle(AgroTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            AgroPrimaryButton(title: "Entrar novamente") {
                dismiss()
                Task { await session.signOut() }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }
}
