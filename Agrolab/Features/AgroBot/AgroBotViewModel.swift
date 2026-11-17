//
//  AgroBotViewModel.swift
//  Agrolab
//

import Foundation
import Observation

/// Estado da tela do AgroBot (UC06): conversa, streaming das respostas, ditado e leitura em voz alta.
@MainActor
@Observable
final class AgroBotViewModel {
    var status: AgroBotStatus { service.status }
    var downloadRemainingText: String? { service.downloadRemainingText }
    var modelName: String { service.modelName }
    var modelSizeText: String { ByteCountFormatter.string(fromByteCount: service.downloadSizeBytes, countStyle: .file) }

    private(set) var messages: [AgroBotMessage] = []
    private(set) var isGenerating = false
    var input = ""
    var errorMessage: String?

    let greeting: String
    let suggestions = [
        "Minha folha de tomate está com manchas",
        "Quando devo adubar o milho?",
        "Como corrigir um solo ácido?",
    ]

    /// O que o AgroBot sabe da lavoura (UC06, passo 2; FE01 quando vazio).
    var contextLine: String { service.context.summaryLine }
    var hasFarmContext: Bool { service.context.hasHistory }

    var canSend: Bool {
        status == .ready && !isGenerating && !isListening && !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isListening: Bool { voice.isListening }
    var canListen: Bool { status == .ready && !isGenerating }
    var speakingMessageID: UUID? { voice.speakingMessageID }
    var naturalVoiceStatus: NaturalVoiceStatus { voice.naturalVoiceStatus }
    var naturalVoiceFallbackReason: String? { voice.naturalVoiceFallbackReason }
    var autoSpeak: Bool {
        get { voice.autoSpeak }
        set { voice.autoSpeak = newValue }
    }
    let naturalVoiceSizeText: String

    private let service: AgroBotService
    private let voice: VoiceService
    private let ownerID: String
    private let producerName: String?

    private var chatID: UUID?
    @ObservationIgnored private var pendingTopic: AgroBotTopic?
    @ObservationIgnored private var lastSent: (text: String, at: Date)?
    @ObservationIgnored private var listeningTask: Task<Void, Never>?
    @ObservationIgnored private var silenceTask: Task<Void, Never>?
    private let lateDictationWindow: TimeInterval = 2
    private let silenceTimeout: Duration = .seconds(3)
    private let streamingRefreshInterval: Duration = .milliseconds(120)

    init(service: AgroBotService, voice: VoiceService, user: User) {
        self.service = service
        self.voice = voice
        self.ownerID = user.id
        self.producerName = user.name
        self.greeting = "Oi, \(user.firstName)! Sou o AgroBot. Posso tirar dúvidas sobre sua lavoura, pragas, solo e manejo. Como posso ajudar?"
        self.naturalVoiceSizeText = ByteCountFormatter.string(fromByteCount: voice.naturalVoiceDownloadSizeBytes, countStyle: .file)
    }

    // MARK: Ciclo de vida

    /// Abre a conversa sobre um assunto vindo de outra tela (ex.: diagnóstico de praga).
    func open(topic: AgroBotTopic) {
        pendingTopic = topic
        if chatID != nil { openPendingTopic() }
    }

    func onAppear() async {
        if pendingTopic != nil {
            openPendingTopic()
        } else if chatID == nil {
            do {
                let conversation = try service.loadConversation(ownerID: ownerID)
                chatID = conversation.chatID
                messages = conversation.messages
            } catch {
                errorMessage = "Não foi possível abrir a conversa: \(error.localizedDescription)"
            }
        }
        voice.refreshNaturalVoiceStatus()
        await service.prepare()
    }

    func onDisappear() {
        listeningTask?.cancel()
        voice.release()
        guard !isGenerating else { return }
        service.releaseModel()
    }

    private func openPendingTopic() {
        guard let topic = pendingTopic else { return }
        pendingTopic = nil
        voice.stopSpeaking()
        do {
            let conversation = try service.startConversation(about: topic, ownerID: ownerID)
            chatID = conversation.chatID
            messages = conversation.messages
            errorMessage = nil
        } catch {
            errorMessage = "Não foi possível abrir a conversa: \(error.localizedDescription)"
        }
    }

    // MARK: Modelo

    func download() { service.startDownload() }
    func cancelDownload() { service.cancelDownload() }
    func retry() async { await service.retry() }

    func deleteModel() async {
        do {
            try await service.deleteModel()
        } catch {
            errorMessage = "Não foi possível apagar o AgroBot do aparelho: \(error.localizedDescription)"
        }
    }

    // MARK: Conversa

    func send(speakReply: Bool = false) async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let chatID, status == .ready, !isGenerating else { return }

        input = ""
        lastSent = (text, Date())
        errorMessage = nil
        voice.stopSpeaking()

        messages.append(AgroBotMessage(role: .user, content: text))
        messages.append(AgroBotMessage(role: .assistant, content: ""))
        let index = messages.count - 1
        isGenerating = true
        defer { isGenerating = false }

        do {
            let clock = ContinuousClock()
            var lastRefresh = clock.now - streamingRefreshInterval
            var reply = ""
            for try await partial in service.send(text, in: chatID, producerName: producerName) {
                reply = partial
                if clock.now - lastRefresh >= streamingRefreshInterval {
                    messages[index].content = partial
                    lastRefresh = clock.now
                }
            }
            messages[index].content = reply
            if reply.isEmpty {
                errorMessage = "O AgroBot não respondeu. Tente de novo."
                messages.removeSubrange((index - 1)...index)
                input = text
            } else if autoSpeak || speakReply {
                speak(messages[index])
            }
        } catch {
            errorMessage = error.localizedDescription
            messages.removeSubrange((index - 1)...index)
            input = text
        }
    }

    func send(suggestion: String) async {
        input = suggestion
        await send()
    }

    /// O ditado do teclado às vezes entrega o texto depois do envio: descarta essa sobra.
    func inputDidChange() {
        guard let lastSent, Date().timeIntervalSince(lastSent.at) < lateDictationWindow else { return }
        let current = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !current.isEmpty, lastSent.text.contains(current) else { return }
        input = ""
    }

    func startNewConversation() {
        voice.stopSpeaking()
        do {
            let conversation = try service.startNewConversation(ownerID: ownerID)
            chatID = conversation.chatID
            messages = conversation.messages
            errorMessage = nil
        } catch {
            errorMessage = "Não foi possível criar a conversa: \(error.localizedDescription)"
        }
    }

    // MARK: Voz

    func toggleListening() {
        if isListening {
            voice.stopListening()
            return
        }
        guard canListen, listeningTask == nil else { return }
        errorMessage = nil
        let typed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        listeningTask = Task {
            defer {
                silenceTask?.cancel()
                listeningTask = nil
            }
            do {
                var spoken = ""
                for try await transcript in try await voice.listen() {
                    spoken = transcript
                    input = typed.isEmpty ? transcript : "\(typed) \(transcript)"
                    restartSilenceTimer()
                }
                if !spoken.isEmpty, !Task.isCancelled {
                    await send(speakReply: true)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func restartSilenceTimer() {
        silenceTask?.cancel()
        silenceTask = Task { [voice, silenceTimeout] in
            try? await Task.sleep(for: silenceTimeout)
            guard !Task.isCancelled else { return }
            voice.stopListening()
        }
    }

    func toggleSpeaking(_ message: AgroBotMessage) {
        if speakingMessageID == message.id {
            voice.stopSpeaking()
        } else {
            speak(message)
        }
    }

    func downloadNaturalVoice() { voice.startNaturalVoiceDownload() }
    func cancelNaturalVoiceDownload() { voice.cancelNaturalVoiceDownload() }

    func deleteNaturalVoice() {
        do {
            try voice.deleteNaturalVoice()
        } catch {
            errorMessage = "Não foi possível apagar a voz: \(error.localizedDescription)"
        }
    }

    private func speak(_ message: AgroBotMessage) {
        voice.speak(message.content, messageID: message.id) { [weak self] error in
            self?.errorMessage = "Não foi possível ler a resposta: \(error.localizedDescription)"
        }
    }
}
