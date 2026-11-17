//
//  AgroBotInfoCards.swift
//  Agrolab
//

import SwiftUI

/// Aviso fixo de que o AgroBot não substitui o agrônomo (RN20).
struct AgroBotNotice: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(AgroTheme.Colors.primaryDark)
                .accessibilityHidden(true)
            Text("Orientação geral de apoio, feita por IA. Não substitui um engenheiro agrônomo.")
                .font(.subheadline)
                .foregroundStyle(AgroTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AgroTheme.Colors.primarySoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Contexto da lavoura usado nas respostas (UC06, passo 2). Sem dados, avisa que a resposta é geral (FE01).
struct AgroBotContextCard: View {
    let text: String
    let hasHistory: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: hasHistory ? "leaf.fill" : "tray")
                .foregroundStyle(hasHistory ? AgroTheme.Colors.primary : AgroTheme.Colors.textSecondary)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(AgroTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AgroTheme.Colors.sand, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AgroTheme.Colors.sandBorder)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Sugestões de perguntas exibidas antes da primeira mensagem.
struct AgroBotSuggestions: View {
    let suggestions: [String]
    var isDisabled = false
    let onSelect: (String) -> Void

    @State private var taps = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Experimente perguntar")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AgroTheme.Colors.textSecondary)
            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    taps += 1
                    onSelect(suggestion)
                } label: {
                    Text(suggestion)
                        .font(.body.weight(.medium))
                        .foregroundStyle(AgroTheme.Colors.primaryDark)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .frame(minHeight: 44)
                        .background(AgroTheme.Colors.surface, in: Capsule())
                        .overlay { Capsule().strokeBorder(AgroTheme.Colors.primary.opacity(0.6)) }
                }
                .buttonStyle(AgroPressStyle())
                .disabled(isDisabled)
            }
        }
        .sensoryFeedback(.selection, trigger: taps)
    }
}

#Preview {
    VStack(spacing: 16) {
        AgroBotNotice()
        AgroBotContextCard(text: "Ainda não há dados da sua lavoura no app. As respostas serão gerais.", hasHistory: false)
        AgroBotContextCard(text: "Usando 2 diagnósticos de praga recentes (Tomate, Milho) para responder.", hasHistory: true)
        AgroBotSuggestions(suggestions: ["Quando devo adubar o milho?", "Como corrigir um solo ácido?"]) { _ in }
    }
    .padding()
    .background(AgroTheme.Colors.background)
}
