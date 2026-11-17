//
//  QwenAgroBotEngine.swift
//  Agrolab
//

import Foundation
import MLX
import MLXLMCommon

/// Motor do AgroBot: ciclo de vida do modelo (download, carga, liberação) e geração de respostas.
@MainActor
protocol AgroBotEngine: AnyObject {
    var modelName: String { get }
    var downloadSizeBytes: Int64 { get }
    var isLoaded: Bool { get }
    var hasDownloadInProgress: Bool { get }

    func unsupportedReason() -> String?
    func isDownloaded() -> Bool
    func downloadWarnings() async -> [String]
    func download(progress: @escaping @MainActor (Double) -> Void) async throws
    func load() async throws
    func unload()
    func delete() throws

    func startConversation(history: [AgroBotMessage], appData: String?)
    func reply(to text: String) -> AsyncThrowingStream<String, Error>
}

/// Implementação com o Qwen 3.5 4B rodando no próprio iPhone (MLX). Funciona sem internet depois do download.
@MainActor
final class QwenAgroBotEngine: AgroBotEngine {
    private let store = QwenModelStore()
    private var inference: QwenInferenceSource?
    private var loading: Task<QwenInferenceSource, Error>?
    private var pendingHistory: [AgroBotMessage] = []
    private var pendingAppData: String?

    private let minimumRAMBytes: UInt64 = 7_000_000_000
    private let requiredFreeSpaceBytes: Int64 = 4_000_000_000
    private let maxHistoryMessages = 12

    var modelName: String { store.displayName }
    var downloadSizeBytes: Int64 { store.downloadSizeBytes }
    var isLoaded: Bool { inference != nil }
    var hasDownloadInProgress: Bool { store.hasDownloadInProgress }

    func unsupportedReason() -> String? {
        if DeviceCapabilities.isSimulator {
            return "O AgroBot roda na GPU de um iPhone físico. Ele não funciona no simulador."
        }
        if DeviceCapabilities.physicalMemoryBytes < minimumRAMBytes {
            return "Este aparelho não tem memória suficiente para o AgroBot. É preciso um iPhone 15 Pro ou mais novo."
        }
        return nil
    }

    func isDownloaded() -> Bool {
        store.isDownloaded()
    }

    func downloadWarnings() async -> [String] {
        var warnings: [String] = []
        let free = DeviceCapabilities.freeDiskSpaceBytes()
        if free < requiredFreeSpaceBytes {
            let needed = ByteCountFormatter.string(fromByteCount: requiredFreeSpaceBytes, countStyle: .file)
            let available = ByteCountFormatter.string(fromByteCount: free, countStyle: .file)
            warnings.append("Espaço insuficiente: são necessários \(needed) livres e há \(available).")
        }
        if await DeviceCapabilities.isOnExpensiveNetwork() {
            warnings.append("Você está usando dados móveis. Recomendamos conectar a uma rede Wi-Fi antes de baixar.")
        }
        return warnings
    }

    func download(progress: @escaping @MainActor (Double) -> Void) async throws {
        try await store.download(progress: progress)
    }

    func load() async throws {
        _ = try await loadIfNeeded()
    }

    func unload() {
        guard inference != nil else { return }
        inference = nil
        Memory.clearCache()
    }

    func delete() throws {
        unload()
        try store.delete()
    }

    func startConversation(history: [AgroBotMessage], appData: String?) {
        pendingHistory = history
        pendingAppData = appData
        inference?.startConversation(history: recent(history), appData: appData)
    }

    func reply(to text: String) -> AsyncThrowingStream<String, Error> {
        guard let inference else {
            return AsyncThrowingStream { $0.finish(throwing: AgroBotEngineError.notReady) }
        }
        return inference.reply(to: text)
    }

    private func loadIfNeeded() async throws -> QwenInferenceSource {
        if let inference { return inference }
        if let loading { return try await loading.value }
        let task = Task { @MainActor [store] in try await QwenInferenceSource(container: store.loadContainer()) }
        loading = task
        defer { loading = nil }
        let inference = try await task.value
        inference.startConversation(history: recent(pendingHistory), appData: pendingAppData)
        self.inference = inference
        return inference
    }

    private func recent(_ history: [AgroBotMessage]) -> [LLMMessage] {
        var messages = history.suffix(maxHistoryMessages)
        if messages.first?.role == .assistant { messages = messages.dropFirst() }
        return messages.map { message in
            switch message.role {
            case .user: .user(message.content)
            case .assistant: .assistant(message.content)
            }
        }
    }
}

nonisolated enum AgroBotEngineError: LocalizedError {
    case notReady

    var errorDescription: String? {
        switch self {
        case .notReady: "O AgroBot ainda não está pronto."
        }
    }
}
