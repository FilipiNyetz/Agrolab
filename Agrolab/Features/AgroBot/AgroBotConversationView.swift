//
//  AgroBotConversationView.swift
//  Agrolab
//

import SwiftUI

/// Conversa com o AgroBot: aviso fixo, contexto da lavoura, mensagens em streaming e barra de entrada.
struct AgroBotConversationView: View {
    @Bindable var viewModel: AgroBotViewModel
    @FocusState private var isInputFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private static let bottomID = "bottom"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    AgroBotContextCard(text: viewModel.contextLine, hasHistory: viewModel.hasFarmContext)
                        .padding(.bottom, 4)

                    HStack(alignment: .bottom, spacing: 10) {
                        AgroBotAvatar(size: 36)
                        AgroBotBubble(text: viewModel.greeting, isUser: false)
                    }
                    .frame(maxWidth: AgroBotBubble.maxWidth(for: dynamicTypeSize) + 46, alignment: .leading)

                    if viewModel.messages.isEmpty {
                        AgroBotSuggestions(suggestions: viewModel.suggestions, isDisabled: viewModel.isGenerating) { suggestion in
                            Task { await viewModel.send(suggestion: suggestion) }
                        }
                        .padding(.top, 4)
                    }

                    ForEach(viewModel.messages) { message in
                        AgroBotMessageRow(
                            message: message,
                            isSpeaking: viewModel.speakingMessageID == message.id,
                            onSpeak: { viewModel.toggleSpeaking(message) }
                        )
                    }

                    if let error = viewModel.errorMessage {
                        InlineMessage(kind: .error, message: error)
                    }

                    Color.clear.frame(height: 1).id(Self.bottomID)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(TapGesture().onEnded { isInputFocused = false })
            .onChange(of: viewModel.messages.count) { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
            .onChange(of: viewModel.messages.last?.content.count) { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
            .onAppear { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
        }
        .modifier(AgroBotHaptics(viewModel: viewModel))
        .safeAreaInset(edge: .top, spacing: 0) {
            AgroBotNotice()
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 8)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AgroBotInputBar(
                text: $viewModel.input,
                isFocused: $isInputFocused,
                canSend: viewModel.canSend,
                isListening: viewModel.isListening,
                canListen: viewModel.canListen,
                onSend: { await viewModel.send() },
                onToggleListening: viewModel.toggleListening,
                onTextChange: viewModel.inputDidChange
            )
        }
    }
}

/// Retorno tátil: começar/parar de ouvir, início da resposta e erros.
private struct AgroBotHaptics: ViewModifier {
    let viewModel: AgroBotViewModel

    private var last: AgroBotMessage? { viewModel.messages.last }

    func body(content: Content) -> some View {
        content
            .sensoryFeedback(trigger: viewModel.isListening) { _, isListening in
                isListening ? .impact(weight: .medium) : .impact(weight: .light)
            }
            .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: last?.content.isEmpty) { wasEmpty, isEmpty in
                wasEmpty == true && isEmpty == false && last?.role == .assistant && viewModel.isGenerating
            }
            .sensoryFeedback(.error, trigger: viewModel.errorMessage) { _, new in new != nil }
    }
}
