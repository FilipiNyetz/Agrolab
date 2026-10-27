//
//  PestModels.swift
//  Agrolab
//

import Foundation

/// Natureza do problema identificado; define a recomendação exibida.
nonisolated enum IssueKind: Sendable {
    case healthy, fungal, bacterial, viral, mite, other
}

/// Resultado de uma classificação, já traduzido para exibição.
nonisolated struct PestDiagnosis: Identifiable, Sendable {
    let id = UUID()
    /// Rótulo cru devolvido pelo modelo (ex.: `Tomato___Early_blight`).
    let label: String
    let confidence: Double
    /// Demais hipóteses, da mais para a menos provável.
    let alternatives: [Alternative]

    struct Alternative: Identifiable, Sendable {
        var id: String { label }
        let label: String
        let confidence: Double
    }

    /// Abaixo disso o resultado é tratado como inconclusivo.
    static let minimumConfidence = 0.6

    var isConclusive: Bool { confidence >= Self.minimumConfidence }
    var isHealthy: Bool { Self.kind(for: label) == .healthy }
    var cropName: String { Self.cropName(for: label) }
    var title: String { Self.displayName(for: label) }
    var recommendation: String { Self.recommendation(for: Self.kind(for: label)) }

    // MARK: Tradução dos rótulos do modelo (PlantVillage)

    private static let crops: [String: String] = [
        "Apple": "Maçã", "Blueberry": "Mirtilo", "Cherry_(including_sour)": "Cereja",
        "Corn_(maize)": "Milho", "Grape": "Uva", "Orange": "Laranja", "Peach": "Pêssego",
        "Pepper,_bell": "Pimentão", "Potato": "Batata", "Raspberry": "Framboesa",
        "Soybean": "Soja", "Squash": "Abóbora", "Strawberry": "Morango", "Tomato": "Tomate",
    ]

    private static let issues: [String: (name: String, kind: IssueKind)] = [
        "Apple_scab": ("Sarna", .fungal),
        "Black_rot": ("Podridão-negra", .fungal),
        "Cedar_apple_rust": ("Ferrugem-do-cedro", .fungal),
        "Powdery_mildew": ("Oídio", .fungal),
        "Cercospora_leaf_spot Gray_leaf_spot": ("Mancha-de-cercospora", .fungal),
        "Common_rust_": ("Ferrugem-comum", .fungal),
        "Northern_Leaf_Blight": ("Helmintosporiose (crestamento-foliar)", .fungal),
        "Esca_(Black_Measles)": ("Esca (sarampo-negro)", .fungal),
        "Leaf_blight_(Isariopsis_Leaf_Spot)": ("Mancha-foliar (Isariopsis)", .fungal),
        "Haunglongbing_(Citrus_greening)": ("Greening (Huanglongbing)", .bacterial),
        "Bacterial_spot": ("Mancha-bacteriana", .bacterial),
        "Early_blight": ("Pinta-preta (requeima precoce)", .fungal),
        "Late_blight": ("Requeima", .fungal),
        "Leaf_scorch": ("Queima-das-folhas", .fungal),
        "Leaf_Mold": ("Mofo-foliar", .fungal),
        "Septoria_leaf_spot": ("Septoriose", .fungal),
        "Spider_mites Two-spotted_spider_mite": ("Ácaro-rajado", .mite),
        "Target_Spot": ("Mancha-alvo", .fungal),
        "Tomato_Yellow_Leaf_Curl_Virus": ("Vírus do enrolamento-amarelo (TYLCV)", .viral),
        "Tomato_mosaic_virus": ("Vírus do mosaico do tomateiro", .viral),
        "healthy": ("Planta saudável", .healthy),
    ]

    private static func parts(of label: String) -> (crop: String, issue: String) {
        let pieces = label.components(separatedBy: "___")
        return (pieces.first ?? label, pieces.count > 1 ? pieces[1] : "")
    }

    static func cropName(for label: String) -> String {
        let crop = parts(of: label).crop
        return crops[crop] ?? crop.replacingOccurrences(of: "_", with: " ")
    }

    static func kind(for label: String) -> IssueKind {
        issues[parts(of: label).issue]?.kind ?? .other
    }

    /// Ex.: `Tomato___Early_blight` → "Tomate · Pinta-preta (requeima precoce)".
    static func displayName(for label: String) -> String {
        let issue = parts(of: label).issue
        let crop = cropName(for: label)
        guard let known = issues[issue] else { return "\(crop) · \(issue.replacingOccurrences(of: "_", with: " "))" }
        return known.kind == .healthy ? "\(crop) · saudável" : "\(crop) · \(known.name)"
    }

    static func recommendation(for kind: IssueKind) -> String {
        switch kind {
        case .healthy:
            return "Nenhum sinal de doença na folha analisada. Continue o monitoramento periódico da lavoura."
        case .fungal:
            return "Doença provocada por fungo, geralmente favorecida por umidade. Retire folhas muito afetadas, evite molhar a folhagem e consulte um agrônomo sobre o fungicida adequado."
        case .bacterial:
            return "Doença bacteriana, disseminada por água, ferramentas e mudas contaminadas. Elimine restos de cultura, higienize ferramentas e procure orientação técnica."
        case .viral:
            return "Doença causada por vírus, transmitida em geral por insetos. Elimine plantas infectadas, controle o inseto vetor e procure orientação técnica."
        case .mite:
            return "Infestação de ácaros, comum em clima quente e seco. Monitore a face inferior das folhas e consulte um agrônomo sobre acaricida e controle biológico."
        case .other:
            return "Procure um engenheiro agrônomo para confirmar o diagnóstico."
        }
    }
}
