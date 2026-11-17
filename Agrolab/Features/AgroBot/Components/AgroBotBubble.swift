//
//  AgroBotBubble.swift
//  Agrolab
//

import SwiftUI

/// Balão de mensagem: verde para o produtor, branco com borda para o AgroBot.
struct AgroBotBubble: View {
    let text: String
    let isUser: Bool

    static let maxWidth: CGFloat = 290

    /// Em tamanhos de acessibilidade o texto fica enorme: o balão passa a usar a largura toda.
    static func maxWidth(for size: DynamicTypeSize) -> CGFloat {
        size.isAccessibilitySize ? .infinity : maxWidth
    }

    private static let radius: CGFloat = AgroTheme.Radius.card
    private static let tipRadius: CGFloat = 6

    static func shape(isUser: Bool) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: radius,
            bottomLeadingRadius: isUser ? radius : tipRadius,
            bottomTrailingRadius: isUser ? tipRadius : radius,
            topTrailingRadius: radius,
            style: .continuous
        )
    }

    var body: some View {
        let shape = Self.shape(isUser: isUser)
        Text(text)
            .font(.body)
            .foregroundStyle(isUser ? AgroTheme.Colors.textOnDark : AgroTheme.Colors.textPrimary)
            .textSelection(.enabled)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isUser ? AgroTheme.Colors.primary : AgroTheme.Colors.surface, in: shape)
            .overlay {
                if !isUser { shape.strokeBorder(AgroTheme.Colors.separator) }
            }
    }
}

/// Três pontos animados enquanto o AgroBot prepara a resposta.
struct AgroBotThinkingBubble: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let lift: CGFloat = 4

    var body: some View {
        let shape = AgroBotBubble.shape(isUser: false)
        PhaseAnimator(reduceMotion ? [-1] : [-1, 0, 1, 2]) { raised in
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(AgroTheme.Colors.primary)
                        .frame(width: 9, height: 9)
                        .offset(y: index == raised ? -Self.lift : 0)
                }
            }
            .padding(.top, Self.lift)
        } animation: { _ in
            .easeInOut(duration: 0.22)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(AgroTheme.Colors.surface, in: shape)
        .overlay(shape.strokeBorder(AgroTheme.Colors.separator))
        .accessibilityElement()
        .accessibilityLabel("O AgroBot está respondendo")
    }
}

/// Avatar do AgroBot: a muda do AgroLab sobre o verde-floresta.
struct AgroBotAvatar: View {
    var size: CGFloat = 40

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [AgroTheme.Colors.forestCard, AgroTheme.Colors.forest],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay { BrandLogo(size: size * 0.6) }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        AgroBotAvatar()
        AgroBotBubble(text: "Oi! Como posso ajudar na sua lavoura?", isUser: false)
        AgroBotBubble(text: "Quando devo adubar o milho?", isUser: true)
            .frame(maxWidth: .infinity, alignment: .trailing)
        AgroBotThinkingBubble()
    }
    .padding()
    .background(AgroTheme.Colors.background)
}
