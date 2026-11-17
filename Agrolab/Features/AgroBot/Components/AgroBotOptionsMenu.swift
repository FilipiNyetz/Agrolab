//
//  AgroBotOptionsMenu.swift
//  Agrolab
//

import SwiftUI

/// Menu da barra: nova conversa, voz e remoção do modelo do aparelho.
struct AgroBotOptionsMenu: View {
    @Bindable var viewModel: AgroBotViewModel
    let onRequestVoiceDownload: () -> Void
    let onRequestModelDeletion: () -> Void

    var body: some View {
        Menu("Opções", systemImage: "ellipsis") {
            Button("Nova conversa", systemImage: "square.and.pencil", action: viewModel.startNewConversation)
            Section("Voz") {
                Toggle("Ler respostas em voz alta", systemImage: "speaker.wave.2", isOn: $viewModel.autoSpeak)
                naturalVoiceItems
            }
            Button("Apagar AgroBot do aparelho", systemImage: "trash", role: .destructive, action: onRequestModelDeletion)
        }
        .disabled(viewModel.isGenerating)
    }

    @ViewBuilder
    private var naturalVoiceItems: some View {
        switch viewModel.naturalVoiceStatus {
        case .unsupported:
            EmptyView()
        case .notDownloaded:
            Button("Baixar voz natural (\(viewModel.naturalVoiceSizeText))", systemImage: "waveform.badge.plus",
                   action: onRequestVoiceDownload)
        case .downloading(let progress):
            Button("Cancelar download da voz (\(progress.formatted(.percent.precision(.fractionLength(0)))))",
                   systemImage: "xmark.circle", action: viewModel.cancelNaturalVoiceDownload)
        case .ready:
            if let reason = viewModel.naturalVoiceFallbackReason {
                Text(reason)
            }
            Button("Apagar voz natural", systemImage: "waveform.slash", role: .destructive,
                   action: viewModel.deleteNaturalVoice)
        case .failed(let message):
            Button("Tentar baixar a voz de novo", systemImage: "arrow.clockwise", action: viewModel.downloadNaturalVoice)
            Text(message)
        }
    }
}
