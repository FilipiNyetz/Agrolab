//
//  AgroBotSetupViews.swift
//  Agrolab
//

import SwiftUI

/// Tudo o que aparece antes do AgroBot estar pronto: verificação, consentimento do download,
/// progresso, carregamento, aparelho incompatível e falha.
struct AgroBotSetupView: View {
    let status: AgroBotStatus
    let modelSizeText: String
    let remainingText: String?
    let onDownload: () -> Void
    let onRetry: () -> Void
    let onCancel: () -> Void

    var body: some View {
        switch status {
        case .checking:
            AgroBotLoadingView(title: "Abrindo o AgroBot…")
        case .loading:
            AgroBotLoadingView(
                title: "Preparando o AgroBot…",
                detail: "Ele roda no seu iPhone, sem internet. Leva alguns segundos."
            )
        default:
            ScrollView {
                content
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch status {
        case .unsupported(let reason):
            StatusCard(symbol: "iphone.slash", title: "AgroBot indisponível neste aparelho", message: reason)

        case .notDownloaded(let warnings):
            AgroBotConsentCard(sizeText: modelSizeText, warnings: warnings, onDownload: onDownload)

        case .downloading(let progress):
            VStack(spacing: 16) {
                AgroBotAvatar(size: 72)
                Text("Baixando o AgroBot")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AgroTheme.Colors.textPrimary)
                ProgressView(value: progress)
                    .tint(AgroTheme.Colors.primary)
                Text("\(Int(progress * 100))%" + (remainingText.map { " · \($0)" } ?? ""))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AgroTheme.Colors.textSecondary)
                    .monospacedDigit()
                Text("Isso pode levar alguns minutos. Use uma internet estável, de preferência Wi-Fi. Pode sair do app: o download continua em segundo plano.")
                    .font(.subheadline)
                    .foregroundStyle(AgroTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                AgroLinkButton(title: "Cancelar download", action: onCancel)
                    .padding(.top, 4)
            }
            .padding(24)
            .background(AgroTheme.Colors.surface, in: RoundedRectangle(cornerRadius: AgroTheme.Radius.card, style: .continuous))
            .accessibilityElement(children: .contain)

        case .failed(let message):
            VStack(spacing: 18) {
                StatusCard(symbol: "exclamationmark.triangle", title: "Algo deu errado", message: message)
                AgroPrimaryButton(title: "Tentar de novo", action: onRetry)
            }

        case .checking, .loading, .ready:
            EmptyView()
        }
    }
}

/// Explica o download do modelo local e pede o consentimento do produtor.
struct AgroBotConsentCard: View {
    let sizeText: String
    let warnings: [String]
    let onDownload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                AgroBotAvatar(size: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Conheça o AgroBot")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AgroTheme.Colors.textPrimary)
                    Text("Seu assistente do campo")
                        .font(.subheadline)
                        .foregroundStyle(AgroTheme.Colors.textSecondary)
                }
            }

            Text("O AgroBot tira dúvidas sobre sua lavoura, pragas, solo e manejo. Para funcionar até onde não pega sinal, ele precisa ser baixado uma vez para este iPhone.")
                .font(.body)
                .foregroundStyle(AgroTheme.Colors.textPrimary)

            VStack(alignment: .leading, spacing: 12) {
                ConsentRow(symbol: "arrow.down.circle", text: "Download feito uma única vez, de \(sizeText)")
                ConsentRow(symbol: "wifi", text: "Pode levar alguns minutos: prefira o Wi-Fi")
                ConsentRow(symbol: "arrow.down.app", text: "Pode sair do app: o download continua em segundo plano")
                ConsentRow(symbol: "antenna.radiowaves.left.and.right.slash", text: "Depois funciona sem internet, no meio da roça")
                ConsentRow(symbol: "lock.shield", text: "Suas conversas e os dados da lavoura não saem do aparelho")
                ConsentRow(symbol: "globe", text: "O download vem do Hugging Face, um site público de modelos de IA. Nenhum dado seu é enviado")
                ConsentRow(symbol: "trash", text: "Você pode apagar o AgroBot do iPhone quando quiser")
            }

            ForEach(warnings, id: \.self) { warning in
                InlineMessage(kind: .error, message: warning)
            }

            AgroPrimaryButton(title: "Baixar o AgroBot", action: onDownload)
                .padding(.top, 4)
        }
        .padding(20)
        .background(AgroTheme.Colors.surface, in: RoundedRectangle(cornerRadius: AgroTheme.Radius.card, style: .continuous))
        .shadow(color: AgroTheme.Colors.forest.opacity(0.06), radius: 16, y: 6)
    }
}

private struct ConsentRow: View {
    let symbol: String
    let text: String

    var body: some View {
        Label {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(AgroTheme.Colors.textSecondary)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(AgroTheme.Colors.primary)
        }
    }
}

private struct StatusCard: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(AgroTheme.Colors.primary)
                .frame(width: 96, height: 96)
                .background(AgroTheme.Colors.primarySoft, in: Circle())
                .accessibilityHidden(true)
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(AgroTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.body)
                .foregroundStyle(AgroTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(AgroTheme.Colors.surface, in: RoundedRectangle(cornerRadius: AgroTheme.Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Estado de espera com o avatar do AgroBot.
struct AgroBotLoadingView: View {
    let title: String
    var detail: String?

    var body: some View {
        VStack(spacing: 16) {
            AgroBotAvatar(size: 72)
            ProgressView()
                .tint(AgroTheme.Colors.primaryDark)
            Text(title)
                .font(.headline)
                .foregroundStyle(AgroTheme.Colors.textPrimary)
            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(AgroTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Consentimento") {
    ScrollView {
        AgroBotConsentCard(sizeText: "3 GB", warnings: ["Você está usando dados móveis. Recomendamos conectar a uma rede Wi-Fi antes de baixar."]) {}
            .padding()
    }
    .background(AgroTheme.Colors.background)
}

#Preview("Baixando") {
    AgroBotSetupView(status: .downloading(progress: 0.42), modelSizeText: "3 GB", remainingText: "faltam cerca de 6 min",
                     onDownload: {}, onRetry: {}, onCancel: {})
        .background(AgroTheme.Colors.background)
}
