//
//  InlineMessage.swift
//  Agrolab
//

import SwiftUI

/// Mensagem inline (erro, sucesso ou informação) exibida dentro dos formulários.
struct InlineMessage: View {
    enum Kind {
        case error, success, info

        var icon: String {
            switch self {
            case .error: return "exclamationmark.triangle.fill"
            case .success: return "checkmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }

        var foreground: Color {
            switch self {
            case .error: return AgroTheme.Colors.danger
            case .success: return AgroTheme.Colors.success
            case .info: return AgroTheme.Colors.primaryDark
            }
        }

        var background: Color {
            switch self {
            case .error: return AgroTheme.Colors.dangerSoft
            case .success: return AgroTheme.Colors.successSoft
            case .info: return AgroTheme.Colors.primarySoft
            }
        }
    }

    let kind: Kind
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: kind.icon)
                .font(.system(size: 16, weight: .semibold))
            Text(message)
                .font(.system(size: 15, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(kind.foreground)
        .padding(14)
        .background(kind.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .transition(.opacity.combined(with: .move(edge: .top)))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 12) {
        InlineMessage(kind: .error, message: "E-mail ou senha incorretos.")
        InlineMessage(kind: .success, message: "Senha redefinida com sucesso.")
        InlineMessage(kind: .info, message: "Enviamos um código para o seu e-mail.")
    }
    .padding()
}
