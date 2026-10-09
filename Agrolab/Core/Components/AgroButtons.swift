//
//  AgroButtons.swift
//  Agrolab
//

import SwiftUI

/// Botão principal verde, largura total, com estado de carregamento.
struct AgroPrimaryButton: View {
    let title: String
    var isLoading = false
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .opacity(isLoading ? 0 : 1)
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                LinearGradient(
                    colors: [AgroTheme.Colors.primary, AgroTheme.Colors.primaryDark],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: AgroTheme.Radius.button, style: .continuous)
            )
            .shadow(color: AgroTheme.Colors.primary.opacity(isEnabled ? 0.28 : 0), radius: 12, y: 6)
        }
        .buttonStyle(AgroPressStyle())
        .disabled(isLoading)
        .opacity(isEnabled ? 1 : 0.55)
        .animation(.easeOut(duration: 0.2), value: isEnabled)
        .animation(.easeOut(duration: 0.2), value: isLoading)
    }
}

/// Botão secundário com contorno verde.
struct AgroOutlineButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AgroTheme.Colors.primaryDark)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(AgroTheme.Colors.surface, in: RoundedRectangle(cornerRadius: AgroTheme.Radius.button, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AgroTheme.Radius.button, style: .continuous)
                        .strokeBorder(AgroTheme.Colors.primary, lineWidth: 1.5)
                }
        }
        .buttonStyle(AgroPressStyle())
    }
}

/// Botão em formato de pílula branca (tela de boas-vindas).
struct AgroPillButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AgroTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(.white, in: Capsule())
                .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
        }
        .buttonStyle(AgroPressStyle())
    }
}

/// Botão em texto, sem fundo.
struct AgroLinkButton: View {
    let title: String
    var color: Color = AgroTheme.Colors.primaryDark
    var font: Font = .system(size: 17, weight: .semibold)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(font)
                .foregroundStyle(color)
        }
        .buttonStyle(.plain)
    }
}

/// Leve escala ao pressionar.
struct AgroPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 16) {
        AgroPrimaryButton(title: "Entrar") {}
        AgroPrimaryButton(title: "Entrar", isLoading: true) {}
        AgroPrimaryButton(title: "Entrar") {}.disabled(true)
        AgroOutlineButton(title: "Criar nova conta") {}
        AgroPillButton(title: "Criar conta gratuita") {}
    }
    .padding()
    .background(AgroTheme.Colors.background)
}
