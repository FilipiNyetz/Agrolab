//
//  AgroBotView.swift
//  Agrolab
//

import SwiftUI

/// Aba do AgroBot (UC06): prepara o assistente local e mostra a conversa quando ele está pronto.
struct AgroBotView: View {
    @Environment(AppContainer.self) private var container
    @Environment(SessionManager.self) private var session
    @State private var viewModel: AgroBotViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    AgroBotContentView(viewModel: viewModel)
                } else {
                    AgroBotLoadingView(title: "Abrindo o AgroBot…")
                }
            }
            .background {
                LinearGradient(
                    stops: [
                        .init(color: AgroTheme.Colors.backgroundAccent, location: 0),
                        .init(color: AgroTheme.Colors.background, location: 0.35),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
            .navigationTitle("AgroBot")
            .navigationSubtitle("Seu assistente do campo")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(AgroTheme.Colors.primaryDark)
        .task {
            if viewModel == nil, let user = session.currentUser {
                viewModel = container.makeAgroBotViewModel(user: user)
            }
            consumePendingTopic()
        }
        .onChange(of: container.agroBotLauncher.pendingTopic) { consumePendingTopic() }
    }

    private func consumePendingTopic() {
        guard let viewModel, let topic = container.agroBotLauncher.takeTopic() else { return }
        viewModel.open(topic: topic)
    }
}

private struct AgroBotContentView: View {
    @Bindable var viewModel: AgroBotViewModel
    @State private var showingDeleteConfirmation = false
    @State private var showingVoiceDownloadConfirmation = false

    var body: some View {
        Group {
            if viewModel.status == .ready {
                AgroBotConversationView(viewModel: viewModel)
            } else {
                AgroBotSetupView(
                    status: viewModel.status,
                    modelSizeText: viewModel.modelSizeText,
                    remainingText: viewModel.downloadRemainingText,
                    onDownload: viewModel.download,
                    onRetry: { Task { await viewModel.retry() } },
                    onCancel: viewModel.cancelDownload
                )
            }
        }
        .sensoryFeedback(trigger: viewModel.status) { old, new in
            if case .failed = new { return .error }
            if case .downloading = old, new == .loading || new == .ready { return .success }
            return nil
        }
        .sensoryFeedback(trigger: viewModel.naturalVoiceStatus) { old, new in
            if case .failed = new { return .error }
            if case .downloading = old, new == .ready { return .success }
            return nil
        }
        .toolbar {
            if viewModel.status == .ready {
                ToolbarItem(placement: .topBarTrailing) {
                    AgroBotOptionsMenu(
                        viewModel: viewModel,
                        onRequestVoiceDownload: { showingVoiceDownloadConfirmation = true },
                        onRequestModelDeletion: { showingDeleteConfirmation = true }
                    )
                }
            }
        }
        .confirmationDialog("Baixar a voz natural?", isPresented: $showingVoiceDownloadConfirmation, titleVisibility: .visible) {
            Button("Baixar (\(viewModel.naturalVoiceSizeText))", action: viewModel.downloadNaturalVoice)
        } message: {
            Text("Uma voz brasileira mais natural para ler as respostas, que funciona sem internet. Ocupa \(viewModel.naturalVoiceSizeText); recomendamos usar Wi-Fi. Até terminar, as respostas são lidas com a voz do iPhone.")
        }
        .confirmationDialog("Apagar o AgroBot do iPhone?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Apagar", role: .destructive) { Task { await viewModel.deleteModel() } }
        } message: {
            Text("Libera cerca de \(viewModel.modelSizeText) no iPhone. Suas conversas continuam salvas. Para usar o AgroBot de novo, será preciso baixá-lo outra vez.")
        }
        .task { await viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
    }
}

#Preview {
    let container = AppContainer()
    AgroBotView()
        .environment(container)
        .environment(container.session)
}
