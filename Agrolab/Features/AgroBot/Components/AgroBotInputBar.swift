//
//  AgroBotInputBar.swift
//  Agrolab
//

import SwiftUI

/// Campo de mensagem com botão que alterna entre falar (microfone), parar e enviar.
struct AgroBotInputBar: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let canSend: Bool
    var isListening = false
    var canListen = true
    let onSend: () async -> Void
    var onToggleListening: () -> Void = {}
    var onTextChange: () -> Void = {}

    /// Dá tempo do ditado do teclado entregar a última palavra antes do envio.
    private static let dictationCommitDelay: Duration = .milliseconds(150)
    private static let height: CGFloat = 48

    @State private var sends = 0

    private var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField(isListening ? "Ouvindo…" : "Escreva ou fale sua dúvida…", text: $text, axis: .vertical)
                .lineLimit(1...5)
                .font(.body)
                .foregroundStyle(AgroTheme.Colors.textPrimary)
                .tint(AgroTheme.Colors.primaryDark)
                .focused(isFocused)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .frame(minHeight: Self.height)
                .background(AgroTheme.Colors.surface, in: RoundedRectangle(cornerRadius: Self.height / 2, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Self.height / 2, style: .continuous)
                        .strokeBorder(isFocused.wrappedValue ? AgroTheme.Colors.fieldBorder : AgroTheme.Colors.separator,
                                      lineWidth: isFocused.wrappedValue ? 1.5 : 1)
                }
                .disabled(isListening)

            if isListening {
                CircleActionButton(systemImage: "stop.fill", label: "Parar e enviar", action: onToggleListening)
                    .symbolEffect(.pulse, isActive: isListening)
            } else if isEmpty {
                CircleActionButton(systemImage: "mic.fill", label: "Falar") {
                    isFocused.wrappedValue = false
                    onToggleListening()
                }
                .disabled(!canListen)
                .accessibilityHint("Toque e fale. Toque de novo, ou fique em silêncio, para enviar.")
            } else {
                CircleActionButton(systemImage: "arrow.up", label: "Enviar", action: send)
                    .disabled(!canSend)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.bar)
        .sensoryFeedback(.impact(weight: .light), trigger: sends)
        .onChange(of: text) { onTextChange() }
    }

    private func send() {
        sends += 1
        isFocused.wrappedValue = false
        Task {
            try? await Task.sleep(for: Self.dictationCommitDelay)
            await onSend()
        }
    }
}

/// Botão redondo verde do AgroLab (48 pt, acima do alvo mínimo de toque).
private struct CircleActionButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(
                    LinearGradient(colors: [AgroTheme.Colors.primary, AgroTheme.Colors.primaryDark],
                                   startPoint: .top, endPoint: .bottom),
                    in: Circle()
                )
                .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(AgroPressStyle())
        .accessibilityLabel(label)
    }
}

private struct AgroBotInputBarPreview: View {
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack {
            Spacer()
            AgroBotInputBar(text: $text, isFocused: $focused, canSend: !text.isEmpty) {}
        }
        .background(AgroTheme.Colors.background)
    }
}

#Preview {
    AgroBotInputBarPreview()
}
