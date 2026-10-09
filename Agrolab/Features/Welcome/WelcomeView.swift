//
//  WelcomeView.swift
//  Agrolab
//

import SwiftUI

/// Tela inicial: imagem de fundo, logotipo e chamadas para cadastro e login.
struct WelcomeView: View {
    @Environment(AuthRouter.self) private var router

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            BrandLogo(size: 150)
                .shadow(color: .black.opacity(0.35), radius: 18, y: 10)

            BrandWordmark(size: 50)
                .padding(.top, 22)

            Text("Laboratório de bolso para\npequenos produtores rurais")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(AgroTheme.Colors.leaf)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 10)

            Spacer()
            Spacer()

            Button {
                router.push(.register)
            } label: {
                Text("Criar conta gratuita")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.white)
            .foregroundStyle(AgroTheme.Colors.forest)

            AgroLinkButton(
                title: "Já tenho uma conta – entrar",
                color: AgroTheme.Colors.leaf,
                font: .system(size: 19, weight: .medium)
            ) {
                router.push(.login)
            }
            .padding(.top, 22)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { WelcomeBackground() }
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// Fundo: imagem do catálogo ("backgroundImage") sobre um verde-escuro, com gradiente para leitura.
private struct WelcomeBackground: View {
    var body: some View {
        ZStack {
            AgroTheme.Colors.forestDeep

            // Color.clear assume o tamanho proposto; a imagem no overlay preenche sem alterar o layout.
            Color.clear
                .overlay {
                    Image("backgroundImage")
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
                .overlay(AgroTheme.Colors.forestDeep.opacity(0.35))

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.45), location: 0),
                    .init(color: .clear, location: 0.35),
                    .init(color: .clear, location: 0.6),
                    .init(color: .black.opacity(0.80), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

#Preview {
    NavigationStack {
        WelcomeView()
    }
    .environment(AuthRouter())
}
