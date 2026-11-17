//
//  AgroBotService.swift
//  Agrolab
//

import Foundation
import Observation

/// Orquestra o UC06: prepara o modelo local, abre a sessão de conversa do produtor, aplica os guardrails
/// de escopo (FA01) e injeta o contexto da lavoura (RN19) antes de cada pergunta.
@MainActor
@Observable
final class AgroBotService {
    private(set) var status: AgroBotStatus = .checking
    private(set) var downloadRemainingText: String?

    private let engine: AgroBotEngine
    private let chats: AgroBotChatStore
    private let diagnoses: RecentDiagnosesStore
    @ObservationIgnored private var sessionAppData: String?
    @ObservationIgnored private var sessionTopic: String?
    @ObservationIgnored private var downloadTask: Task<Void, Never>?
    @ObservationIgnored private var downloadSample: (fraction: Double, at: Date)?

    private let chatTitle = "Conversa com o AgroBot"
    private let topicChatTitle = "Dúvida sobre diagnóstico"

    init(engine: AgroBotEngine, chats: AgroBotChatStore, diagnoses: RecentDiagnosesStore) {
        self.engine = engine
        self.chats = chats
        self.diagnoses = diagnoses
    }

    var modelName: String { engine.modelName }
    var downloadSizeBytes: Int64 { engine.downloadSizeBytes }
    var context: AgroBotContextBuilder { AgroBotContextBuilder(diagnoses: diagnoses) }

    // MARK: Modelo

    func prepare() async {
        if downloadTask != nil || status == .loading { return }
        if let reason = engine.unsupportedReason() {
            status = .unsupported(reason: reason)
            return
        }
        if engine.isLoaded {
            status = .ready
            return
        }
        if engine.hasDownloadInProgress {
            startDownload()
            return
        }
        if engine.isDownloaded() {
            await loadModel()
            return
        }
        status = .notDownloaded(warnings: await engine.downloadWarnings())
    }

    func startDownload() {
        guard downloadTask == nil else { return }
        status = .downloading(progress: 0)
        downloadSample = nil
        downloadRemainingText = nil
        downloadTask = Task {
            await runDownload()
            downloadTask = nil
        }
    }

    func cancelDownload() {
        downloadTask?.cancel()
    }

    func retry() async {
        if engine.isDownloaded() {
            await loadModel()
        } else {
            startDownload()
        }
    }

    func deleteModel() async throws {
        try engine.delete()
        status = .notDownloaded(warnings: await engine.downloadWarnings())
    }

    /// Libera a memória do modelo ao sair da tela (o download, se houver, continua).
    func releaseModel() {
        guard downloadTask == nil else { return }
        engine.unload()
        if status == .ready { status = .checking }
    }

    private func runDownload() async {
        do {
            try await engine.download { [weak self] progress in
                guard let self, case .downloading = self.status else { return }
                self.status = .downloading(progress: progress)
                self.updateRemainingTime(progress: progress)
            }
            try Task.checkCancellation()
            await loadModel()
        } catch {
            if Task.isCancelled {
                status = .notDownloaded(warnings: await engine.downloadWarnings())
            } else {
                status = .failed(message: "Falha no download: \(error.localizedDescription)")
            }
        }
    }

    private func loadModel() async {
        status = .loading
        do {
            try await engine.load()
            status = .ready
        } catch {
            status = .failed(message: "Não foi possível carregar o AgroBot: \(error.localizedDescription)")
        }
    }

    private func updateRemainingTime(progress: Double) {
        let now = Date()
        guard let sample = downloadSample else {
            downloadSample = (progress, now)
            return
        }
        let elapsed = now.timeIntervalSince(sample.at)
        let done = progress - sample.fraction
        guard elapsed >= 5, done > 0.005 else { return }
        let seconds = elapsed / done * (1 - progress)
        downloadRemainingText = Self.remainingText(seconds: seconds)
    }

    private static func remainingText(seconds: Double) -> String {
        let minutes = Int((seconds / 60).rounded(.up))
        switch minutes {
        case ..<2: return "falta menos de 2 min"
        case ..<60: return "faltam cerca de \(minutes) min"
        default: return "faltam cerca de \(minutes / 60) h \(minutes % 60) min"
        }
    }

    // MARK: Conversa

    struct Conversation {
        let chatID: UUID
        let messages: [AgroBotMessage]
    }

    /// Recupera a última sessão do produtor ou cria uma nova (UC06, passo 4 da seção 10.3.4).
    func loadConversation(ownerID: String) throws -> Conversation {
        let chatID = try chats.latestChatID(ownerID: ownerID) ?? chats.createChat(ownerID: ownerID, title: chatTitle)
        let messages = try chats.messages(in: chatID)
        sessionTopic = try chats.topic(of: chatID)
        resetSession(history: messages)
        return Conversation(chatID: chatID, messages: messages)
    }

    func startConversation(about topic: AgroBotTopic, ownerID: String) throws -> Conversation {
        let chatID = try chats.createChat(ownerID: ownerID, title: topicChatTitle, topic: topic.context)
        let opening = AgroBotMessage(role: .assistant, content: topic.openingMessage)
        try chats.append(opening, to: chatID)
        sessionTopic = topic.context
        resetSession(history: [opening])
        return Conversation(chatID: chatID, messages: [opening])
    }

    func startNewConversation(ownerID: String) throws -> Conversation {
        let chatID = try chats.createChat(ownerID: ownerID, title: chatTitle)
        sessionTopic = nil
        resetSession(history: [])
        return Conversation(chatID: chatID, messages: [])
    }

    /// Envia a pergunta e devolve a resposta em streaming (texto acumulado). Grava pergunta e resposta.
    func send(_ text: String, in chatID: UUID, producerName: String?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                do {
                    let question = AgroBotMessage(role: .user, content: text)

                    if AgroBotScopeGuard.isOutOfScope(text) {
                        continuation.yield(AgroBotScopeGuard.refusal)
                        try chats.append(question, to: chatID)
                        try chats.append(AgroBotMessage(role: .assistant, content: AgroBotScopeGuard.refusal), to: chatID)
                        continuation.finish()
                        return
                    }

                    let summary = Self.appData(context.summary(producerName: producerName), topic: sessionTopic)
                    if summary != sessionAppData {
                        engine.startConversation(history: try chats.messages(in: chatID), appData: summary)
                        sessionAppData = summary
                    }

                    var reply = ""
                    for try await partial in engine.reply(to: text) {
                        if AgroBotScopeGuard.looksLikeCode(partial) {
                            reply = AgroBotScopeGuard.refusal
                            continuation.yield(reply)
                            // A sessão do modelo ficou com a resposta descartada: reabre no próximo envio.
                            sessionAppData = nil
                            break
                        }
                        reply = partial
                        continuation.yield(partial)
                    }

                    if !reply.isEmpty {
                        try chats.append(question, to: chatID)
                        try chats.append(AgroBotMessage(role: .assistant, content: reply), to: chatID)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func deleteConversations(ownerID: String) throws {
        try chats.deleteAll(ownerID: ownerID)
        sessionTopic = nil
        resetSession(history: [])
    }

    private func resetSession(history: [AgroBotMessage]) {
        engine.startConversation(history: history, appData: nil)
        sessionAppData = nil
    }

    private static func appData(_ summary: String, topic: String?) -> String {
        guard let topic else { return summary }
        return summary + "\n\nASSUNTO DESTA CONVERSA (o produtor veio de um diagnóstico de praga feito no app):\n" + topic
    }
}
