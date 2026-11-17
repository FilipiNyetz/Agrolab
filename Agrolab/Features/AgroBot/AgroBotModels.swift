//
//  AgroBotModels.swift
//  Agrolab
//

import Foundation

/// Autor de uma mensagem da conversa com o AgroBot.
nonisolated enum AgroBotRole: String, Codable, Sendable {
    case user
    case assistant
}

/// Mensagem exibida (e persistida) na conversa com o AgroBot.
nonisolated struct AgroBotMessage: Identifiable, Equatable, Sendable {
    let id: UUID
    let role: AgroBotRole
    var content: String
    let createdAt: Date

    init(id: UUID = UUID(), role: AgroBotRole, content: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

/// Estado do modelo local do AgroBot.
nonisolated enum AgroBotStatus: Equatable, Sendable {
    case checking
    case unsupported(reason: String)
    case notDownloaded(warnings: [String])
    case downloading(progress: Double)
    case loading
    case ready
    case failed(message: String)
}

/// Estado da voz natural (Piper) usada para ler as respostas.
nonisolated enum NaturalVoiceStatus: Equatable, Sendable {
    case unsupported(reason: String)
    case notDownloaded
    case downloading(progress: Double)
    case ready
    case failed(message: String)
}

/// Assunto com que a conversa começa quando o produtor vem de outra tela (ex.: um diagnóstico de praga).
nonisolated struct AgroBotTopic: Equatable, Sendable {
    /// Frase curta exibida na abertura da conversa.
    let intro: String
    /// Dados enviados ao modelo como "ASSUNTO DESTA CONVERSA".
    let context: String

    var openingMessage: String {
        "Vamos conversar sobre isso: \(intro) O que você quer saber?"
    }
}

extension AgroBotTopic {
    /// Assunto criado a partir de um diagnóstico do UC03, para tirar dúvidas com o AgroBot (passo 7).
    init(diagnosis: PestDiagnosis) {
        let confidence = diagnosis.confidence.formatted(.percent.precision(.fractionLength(0)))
        if diagnosis.isConclusive {
            intro = "o diagnóstico \(diagnosis.title), com \(confidence) de confiança."
        } else {
            intro = "a foto que você analisou, que deu um resultado inconclusivo."
        }
        context = """
            Cultura: \(diagnosis.cropName)
            Diagnóstico: \(diagnosis.title)
            Confiança do modelo: \(confidence)\(diagnosis.isConclusive ? "" : " (baixa: resultado inconclusivo)")
            Orientação mostrada no app: \(diagnosis.recommendation)
            """
    }
}
