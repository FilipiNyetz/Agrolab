//
//  LoginView.swift
//  Agrolab
//

import SwiftUI

struct LoginView: View {
    @Environment(AuthRouter.self) private var router
    @State private var viewModel: LoginViewModel
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    init(viewModel: LoginViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            AuthHeader(subtitle: "Bem-vindo de volta, produtor") {
                router.pop()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Entrar na conta")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(AgroTheme.Colors.textPrimary)
                        Text("Acesse suas análises e recomendações")
                            .font(.system(size: 17))
                            .foregroundStyle(AgroTheme.Colors.leafMuted)
                    }
                    .padding(.bottom, 8)

                    AgroTextField(
                        icon: "envelope",
                        placeholder: "E-mail",
                        text: $viewModel.email,
                        keyboard: .emailAddress,
                        contentType: .username,
                        submitLabel: .next,
                        autocapitalization: .never,
                        onSubmit: { focusedField = .password }
                    )
                    .focused($focusedField, equals: .email)

                    AgroTextField(
                        icon: "lock.fill",
                        placeholder: "Senha",
                        text: $viewModel.password,
                        isSecure: true,
                        contentType: .password,
                        submitLabel: .go,
                        onSubmit: { Task { await viewModel.submit() } }
                    )
                    .focused($focusedField, equals: .password)

                    HStack {
                        Spacer()
                        AgroLinkButton(title: "Esqueci minha senha", color: AgroTheme.Colors.textPrimary) {
                            router.push(.forgotPassword)
                        }
                    }

                    if let error = viewModel.errorMessage {
                        InlineMessage(kind: .error, message: error)
                    }
                }
                .padding(.horizontal, AgroTheme.Spacing.screen)
                .padding(.top, 32)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: 16) {
                AgroPrimaryButton(title: "Entrar", isLoading: viewModel.isLoading) {
                    focusedField = nil
                    Task { await viewModel.submit() }
                }
                .disabled(!viewModel.canSubmit)

                Rectangle()
                    .fill(AgroTheme.Colors.separator)
                    .frame(height: 1)
                    .padding(.horizontal, 24)

                AgroOutlineButton(title: "Criar nova conta") {
                    router.showRegister()
                }
            }
            .padding(.horizontal, AgroTheme.Spacing.screen)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .background(AgroTheme.Colors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .animation(.easeOut(duration: 0.2), value: viewModel.errorMessage)
        .sensoryFeedback(.error, trigger: viewModel.errorMessage) { _, new in new != nil }
        .onChange(of: viewModel.email) { viewModel.clearError() }
        .onChange(of: viewModel.password) { viewModel.clearError() }
    }
}

#Preview {
    let container = AppContainer()
    NavigationStack {
        LoginView(viewModel: LoginViewModel(authService: container.authService, session: container.session))
    }
    .environment(AuthRouter())
    .environment(container)
}
