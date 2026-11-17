//
//  AgroBotMessageRow.swift
//  Agrolab
//

import SwiftUI

/// Linha da conversa: balão do produtor à direita; do AgroBot à esquerda, com o botão de ouvir.
struct AgroBotMessageRow: View {
    let message: AgroBotMessage
    let isSpeaking: Bool
    let onSpeak: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var bubbleMaxWidth: CGFloat { AgroBotBubble.maxWidth(for: dynamicTypeSize) }

    var body: some View {
        if message.role == .user {
            AgroBotBubble(text: message.content, isUser: true)
                .frame(maxWidth: bubbleMaxWidth, alignment: .trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        } else if message.content.isEmpty {
            AgroBotThinkingBubble()
        } else {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(alignment: .bottom, spacing: 8))
            layout {
                AgroBotBubble(text: message.content, isUser: false)
                SpeakButton(isSpeaking: isSpeaking, action: onSpeak)
            }
            .frame(maxWidth: bubbleMaxWidth + 52, alignment: .leading)
        }
    }
}

private struct SpeakButton: View {
    let isSpeaking: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isSpeaking ? "stop.circle.fill" : "speaker.wave.2.circle")
                .font(.title2)
                .foregroundStyle(AgroTheme.Colors.primaryDark)
                .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                .contentShape(.rect)
        }
        .buttonStyle(.borderless)
        .sensoryFeedback(.impact(weight: .light), trigger: isSpeaking) { _, new in new }
        .accessibilityLabel(isSpeaking ? "Parar leitura" : "Ouvir resposta")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        AgroBotMessageRow(message: AgroBotMessage(role: .user, content: "Minha folha de tomate está com manchas"),
                          isSpeaking: false, onSpeak: {})
        AgroBotMessageRow(message: AgroBotMessage(role: .assistant, content: "Manchas escuras com anéis costumam ser pinta-preta, um fungo que gosta de umidade. Tire as folhas mais atacadas e evite molhar as folhas na irrigação."),
                          isSpeaking: true, onSpeak: {})
        AgroBotMessageRow(message: AgroBotMessage(role: .assistant, content: ""), isSpeaking: false, onSpeak: {})
    }
    .padding()
    .background(AgroTheme.Colors.background)
}
