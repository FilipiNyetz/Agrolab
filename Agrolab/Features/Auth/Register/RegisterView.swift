//
//  RegisterView.swift
//  Agrolab
//

import SwiftUI

struct RegisterView: View {
    @Environment(AuthRouter.self) private var router
    @Environment(AppContainer.self) private var container
    @State private var viewModel: RegisterViewModel
    @FocusState private var focusedField: Field?

    private enum Field { case name, email, password, confirm }

    init(viewModel: RegisterViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            AuthHeader(subtitle: "Comece a cuidar melhor da sua lavoura") {
                router.pop()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Criar conta")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(AgroTheme.Colors.textPrimary)
                        Text("Leva menos de um minuto e é gratuito")
                            .font(.system(size: 17))
                            .foregroundStyle(AgroTheme.Colors.leafMuted)
                    }
                    .padding(.bottom, 8)

                    AgroTextField(
                        icon: "person",
                        placeholder: "Nome completo",
                        text: $viewModel.name,
                        contentType: .name,
                        autocapitalization: .words,
                        onSubmit: { focusedField = .email }
                    )
                    .focused($focusedField, equals: .name)

                    AgroTextField(
                        icon: "envelope",
                        placeholder: "E-mail",
                        text: $viewModel.email,
                        keyboard: .emailAddress,
                        contentType: .emailAddress,
                        autocapitalization: .never,
                        onSubmit: { focusedField = .password }
                    )
                    .focused($focusedField, equals: .email)

                    VStack(alignment: .leading, spacing: 8) {
                        AgroTextField(
                            icon: "lock.fill",
                            placeholder: "Senha",
                            text: $viewModel.password,
                            isSecure: true,
                            contentType: .newPassword,
                            onSubmit: { focusedField = .confirm }
                        )
                        .focused($focusedField, equals: .password)

                        PasswordHint(
                            text: viewModel.passwordHint,
                            isSatisfied: viewModel.isPasswordLongEnough && viewModel.isPasswordWithinLimit,
                            isEmpty: viewModel.password.isEmpty
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        AgroTextField(
                            icon: "lock.rotation",
                            placeholder: "Confirmar senha",
                            text: $viewModel.confirmPassword,
                            isSecure: true,
                            contentType: .newPassword,
                            submitLabel: .done,
                            onSubmit: { focusedField = nil }
                        )
                        .focused($focusedField, equals: .confirm)

                        if !viewModel.confirmPassword.isEmpty && !viewModel.passwordsMatch {
                            PasswordHint(text: "As senhas não coincidem", isSatisfied: false, isEmpty: false)
                        }
                    }

                    TermsToggle(
                        isOn: $viewModel.acceptedTerms,
                        policyVersion: container.environment.privacyPolicyVersion
                    )
                    .padding(.top, 4)

                    if let error = viewModel.errorMessage {
                        InlineMessage(kind: .error, message: error)
                    }

                    AgroPrimaryButton(title: "Criar conta", isLoading: viewModel.isLoading) {
                        focusedField = nil
                        Task { await submit() }
                    }
                    .disabled(!viewModel.canSubmit)
                    .padding(.top, 8)

                    HStack(spacing: 6) {
                        Text("Já tem uma conta?")
                            .foregroundStyle(AgroTheme.Colors.textSecondary)
                        AgroLinkButton(title: "Entrar") {
                            router.showLogin()
                        }
                    }
                    .font(.system(size: 17))
                    .frame(maxWidth: .infinity)
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
        .sensoryFeedback(.error, trigger: viewModel.errorMessage) { _, new in new != nil }
        .onChange(of: viewModel.email) { viewModel.clearError() }
        .onChange(of: viewModel.password) { viewModel.clearError() }
    }

    private func submit() async {
        if let pending = await viewModel.submit() {
            router.push(.verifyEmail(pending))
        }
    }
}

// MARK: - Subviews

private struct PasswordHint: View {
    let text: String
    let isSatisfied: Bool
    let isEmpty: Bool

    private var color: Color {
        if isEmpty { return AgroTheme.Colors.textSecondary }
        return isSatisfied ? AgroTheme.Colors.success : AgroTheme.Colors.danger
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isEmpty ? "info.circle" : (isSatisfied ? "checkmark.circle.fill" : "xmark.circle.fill"))
            Text(text)
        }
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(color)
        .padding(.leading, 6)
        .animation(.easeOut(duration: 0.15), value: text)
    }
}

private struct TermsToggle: View {
    @Binding var isOn: Bool
    let policyVersion: String

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 24))
                    .foregroundStyle(isOn ? AgroTheme.Colors.primary : AgroTheme.Colors.textSecondary)
                    .contentTransition(.symbolEffect(.replace))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Li e aceito os **Termos de Uso** e a **Política de Privacidade**")
                        .font(.system(size: 15))
                        .foregroundStyle(AgroTheme.Colors.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Versão \(policyVersion)")
                        .font(.system(size: 13))
                        .foregroundStyle(AgroTheme.Colors.textSecondary)
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
        .sensoryFeedback(.selection, trigger: isOn)
    }
}

#Preview {
    let container = AppContainer()
    NavigationStack {
        RegisterView(viewModel: RegisterViewModel(authService: container.authService))
    }
    .environment(AuthRouter())
    .environment(container)
}
