//
//  HomeModels.swift
//  Agrolab
//

import Foundation

/// Ações rápidas exibidas na home.
nonisolated enum QuickAction: CaseIterable, Identifiable, Sendable {
    case analyzeSoil, identifyPest, plantingPeriod, agroBot

    var id: Self { self }

    /// Aba correspondente; `nil` quando a ação não tem aba própria e abre uma tela empilhada.
    var tab: AppTab? {
        switch self {
        case .analyzeSoil: return .soil
        case .identifyPest: return .pests
        case .agroBot: return .agroBot
        case .plantingPeriod: return nil
        }
    }

    var detailDescription: String {
        switch self {
        case .analyzeSoil: return "Em breve você poderá registrar e acompanhar análises de solo por aqui."
        case .identifyPest: return "Fotografe a planta e receba a identificação da praga com recomendações."
        case .plantingPeriod: return "Descubra a melhor janela de plantio para cada cultura na sua região."
        case .agroBot: return "Tire dúvidas sobre manejo, adubação e pragas com o assistente do AgroLab."
        }
    }

    var title: String {
        switch self {
        case .analyzeSoil: return "Analisar Solo"
        case .identifyPest: return "Identificar Praga"
        case .plantingPeriod: return "Período Plantio"
        case .agroBot: return "AgroBot"
        }
    }

    var symbolName: String {
        switch self {
        case .analyzeSoil: return "plus.rectangle.on.rectangle"
        case .identifyPest: return "ladybug"
        case .plantingPeriod: return "calendar.badge.clock"
        case .agroBot: return "cpu"
        }
    }
}
