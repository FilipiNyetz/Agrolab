//
//  AgroTextField.swift
//  Agrolab
//

import SwiftUI

/// Campo de texto com ícone, borda verde e suporte a senha (com botão de revelar).
struct AgroTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure = false
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType?
    var submitLabel: SubmitLabel = .next
    var autocapitalization: TextInputAutocapitalization = .sentences
    var onSubmit: (() -> Void)?

    @State private var isRevealed = false
    @FocusState private var isFocused: Bool

    private var prompt: Text {
        Text(placeholder)
            .foregroundStyle(AgroTheme.Colors.textSecondary.opacity(0.75))
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AgroTheme.Colors.primary)
                .frame(width: 24)

            Group {
                if isSecure && !isRevealed {
                    SecureField(placeholder, text: $text, prompt: prompt)
                } else {
                    TextField(placeholder, text: $text, prompt: prompt)
                }
            }
            .font(.system(size: 19))
            .foregroundStyle(AgroTheme.Colors.textPrimary)
            .keyboardType(keyboard)
            .textContentType(contentType)
            .textInputAutocapitalization(isSecure ? .never : autocapitalization)
            .autocorrectionDisabled(isSecure || keyboard == .emailAddress)
            .submitLabel(submitLabel)
            .focused($isFocused)
            .onSubmit { onSubmit?() }

            if isSecure {
                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .font(.system(size: 17))
                        .foregroundStyle(AgroTheme.Colors.textSecondary)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel(isRevealed ? "Ocultar senha" : "Mostrar senha")
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 60)
        .background(AgroTheme.Colors.fieldBackground, in: RoundedRectangle(cornerRadius: AgroTheme.Radius.field, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AgroTheme.Radius.field, style: .continuous)
                .strokeBorder(
                    isFocused ? AgroTheme.Colors.primary : AgroTheme.Colors.fieldBorder.opacity(0.65),
                    lineWidth: isFocused ? 2 : 1.5
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: AgroTheme.Radius.field, style: .continuous))
        .onTapGesture { isFocused = true }
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}

#Preview {
    @Previewable @State var email = ""
    @Previewable @State var password = ""
    VStack(spacing: 16) {
        AgroTextField(icon: "envelope", placeholder: "E-mail", text: $email, keyboard: .emailAddress)
        AgroTextField(icon: "lock.fill", placeholder: "Senha", text: $password, isSecure: true)
    }
    .padding()
    .background(AgroTheme.Colors.background)
}
