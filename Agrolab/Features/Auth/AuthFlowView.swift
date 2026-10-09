//
//  AuthFlowView.swift
//  Agrolab
//

import SwiftUI

/// Fluxo não autenticado: boas-vindas → login / cadastro → verificação / recuperação.
struct AuthFlowView: View {
    @Environment(AppContainer.self) private var container
    @State private var router = AuthRouter()

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            WelcomeView()
                .navigationDestination(for: AuthRoute.self) { route in
                    destination(for: route)
                }
        }
        .environment(router)
        .tint(AgroTheme.Colors.primary)
    }

    @ViewBuilder
    private func destination(for route: AuthRoute) -> some View {
        switch route {
        case .login:
            LoginView(viewModel: LoginViewModel(authService: container.authService, session: container.session))
        case .register:
            RegisterView(viewModel: RegisterViewModel(authService: container.authService))
        case .verifyEmail(let pending):
            VerifyEmailView(
                viewModel: VerifyEmailViewModel(
                    pending: pending,
                    authService: container.authService,
                    session: container.session
                )
            )
        case .forgotPassword:
            ForgotPasswordView(viewModel: ForgotPasswordViewModel(authService: container.authService))
        }
    }
}
