//
//  RootView.swift
//  Agrolab
//

import SwiftUI

/// Decide o que mostrar a partir do estado da sessão.
struct RootView: View {
    @Environment(SessionManager.self) private var session

    var body: some View {
        Group {
            switch session.state {
            case .restoring:
                SplashView()
            case .restoreFailed(let message):
                RestoreFailedView(message: message) {
                    Task { await session.restoreSession() }
                } signOut: {
                    Task { await session.signOut() }
                }
            case .signedOut:
                AuthFlowView()
            case .signedIn:
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: session.isSignedIn)
        .preferredColorScheme(.light)
    }
}

/// Estado de restauração de sessão ao abrir o app.
private struct SplashView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AgroTheme.Colors.forest, AgroTheme.Colors.forestDeep],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                BrandLogo(size: 96)
                BrandWordmark(size: 40)
                ProgressView()
                    .tint(AgroTheme.Colors.leaf)
                    .padding(.top, 12)
            }
        }
    }
}

/// Sem rede ao restaurar a sessão: mantém o token e oferece nova tentativa.
private struct RestoreFailedView: View {
    let message: String
    let retry: () -> Void
    let signOut: () -> Void

    var body: some View {
        ZStack {
            AgroTheme.Colors.background.ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(AgroTheme.Colors.primary)
                    .frame(width: 112, height: 112)
                    .background(AgroTheme.Colors.primarySoft, in: Circle())
                Text("Não foi possível restaurar sua sessão")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AgroTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.system(size: 17))
                    .foregroundStyle(AgroTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)

                AgroPrimaryButton(title: "Tentar novamente", action: retry)
                    .padding(.top, 8)
                AgroLinkButton(title: "Entrar com outra conta", action: signOut)
            }
            .padding(.horizontal, 32)
        }
    }
}

#Preview {
    let container = AppContainer()
    RootView()
        .environment(container)
        .environment(container.session)
}
