//
//  AgroBotContext.swift
//  Agrolab
//

import Foundation
import Observation

/// Diagnósticos de praga feitos nesta sessão do app, usados como contexto do AgroBot (RN19).
/// Quando o histórico em SwiftData (Entrega 2) existir, esta fonte passa a lê-lo de lá.
@MainActor
@Observable
final class RecentDiagnosesStore {
    private(set) var items: [Entry] = []
    private let limit = 10

    struct Entry: Identifiable, Equatable {
        let id: UUID
        let title: String
        let cropName: String
        let confidence: Double
        let isConclusive: Bool
        let date: Date
    }

    func record(_ diagnosis: PestDiagnosis) {
        guard !items.contains(where: { $0.id == diagnosis.id }) else { return }
        let entry = Entry(id: diagnosis.id, title: diagnosis.title, cropName: diagnosis.cropName,
                          confidence: diagnosis.confidence, isConclusive: diagnosis.isConclusive, date: Date())
        items.insert(entry, at: 0)
        if items.count > limit { items.removeLast(items.count - limit) }
    }

    func removeAll() {
        items = []
    }
}

/// Monta o resumo "DADOS DO APP" enviado ao modelo e o que a tela mostra sobre a lavoura (UC06, passo 2).
@MainActor
struct AgroBotContextBuilder {
    let diagnoses: RecentDiagnosesStore

    /// Culturas citadas nos dados disponíveis (no MVP, as dos diagnósticos).
    var crops: [String] {
        var seen: [String] = []
        for crop in diagnoses.items.map(\.cropName) where !seen.contains(crop) { seen.append(crop) }
        return seen
    }

    var hasHistory: Bool { !diagnoses.items.isEmpty }

    /// Frase curta exibida no topo da conversa.
    var summaryLine: String {
        guard hasHistory else {
            return "Ainda não há dados da sua lavoura no app. As respostas serão gerais."
        }
        let count = diagnoses.items.count
        let label = count == 1 ? "1 diagnóstico de praga recente" : "\(count) diagnósticos de praga recentes"
        return "Usando \(label) (\(crops.joined(separator: ", "))) para responder."
    }

    func summary(producerName: String?, now: Date = Date()) -> String {
        let locale = Locale(identifier: "pt_BR")
        var lines = ["DADOS DO APP"]
        lines.append("Hoje: \(now.formatted(.dateTime.day().month(.wide).year().locale(locale)))")
        if let producerName { lines.append("Produtor: \(producerName)") }
        lines.append("Culturas cadastradas: nenhuma ainda.")
        lines.append("Anotações de colheita: nenhuma ainda.")
        if diagnoses.items.isEmpty {
            lines.append("Diagnósticos de praga: nenhum ainda. Não há dados suficientes da lavoura: responda com conhecimento agrícola geral.")
        } else {
            lines.append("Diagnósticos de praga recentes (do mais novo para o mais antigo):")
            for item in diagnoses.items {
                let confidence = item.confidence.formatted(.percent.precision(.fractionLength(0)))
                let when = item.date.formatted(.dateTime.day().month().hour().minute().locale(locale))
                let result = item.isConclusive ? item.title : "inconclusivo (provável \(item.title))"
                lines.append("- \(when): \(result), confiança \(confidence)")
            }
        }
        return lines.joined(separator: "\n")
    }
}
