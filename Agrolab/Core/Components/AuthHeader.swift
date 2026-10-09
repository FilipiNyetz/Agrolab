//
//  AuthHeader.swift
//  Agrolab
//

import SwiftUI

/// Cabeçalho verde-escuro com cantos inferiores arredondados usado nas telas de autenticação.
struct AuthHeader: View {
    let subtitle: String
    var onBack: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let onBack {
                Button(action: onBack) {
                    Label("Voltar", systemImage: "chevron.left")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.10), in: Circle())
                }
                .accessibilityLabel("Voltar")
            }

            HStack(spacing: 18) {
                BrandLogoTile(size: 72)
                BrandWordmark(size: 36)
            }

            Text(subtitle)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AgroTheme.Colors.leaf)
        }
        .padding(.horizontal, AgroTheme.Spacing.screen)
        .padding(.top, onBack == nil ? 24 : 8)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            UnevenRoundedRectangle(
                bottomLeadingRadius: AgroTheme.Radius.header,
                bottomTrailingRadius: AgroTheme.Radius.header,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [AgroTheme.Colors.forest, AgroTheme.Colors.forestDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .ignoresSafeArea(edges: .top)
        }
    }
}

#Preview {
    VStack {
        AuthHeader(subtitle: "Bem-vindo de volta, produtor", onBack: {})
        Spacer()
    }
    .background(AgroTheme.Colors.background)
}
