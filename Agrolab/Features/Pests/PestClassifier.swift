//
//  PestClassifier.swift
//  Agrolab
//

import CoreML
import UIKit
import Vision

nonisolated enum PestClassifierError: LocalizedError {
    case modelNotFound
    case invalidImage
    case noResult

    var errorDescription: String? {
        switch self {
        case .modelNotFound: return "Modelo de classificação não encontrado no app."
        case .invalidImage: return "Não foi possível ler a imagem."
        case .noResult: return "O modelo não retornou nenhum resultado."
        }
    }
}

/// Classifica fotos de folhas com o modelo Core ML `ClassificadorPlantas`, via Vision.
actor PestClassifier {
    private var cachedModel: VNCoreMLModel?

    func classify(_ image: UIImage) throws -> PestDiagnosis {
        guard let cgImage = image.cgImage ?? image.normalizedCGImage() else {
            throw PestClassifierError.invalidImage
        }

        let model = try loadModel()
        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .centerCrop

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: image.cgOrientation)
        try handler.perform([request])

        guard let observations = request.results as? [VNClassificationObservation],
              let best = observations.max(by: { $0.confidence < $1.confidence })
        else { throw PestClassifierError.noResult }

        let alternatives = observations
            .filter { $0 !== best }
            .sorted { $0.confidence > $1.confidence }
            .map { PestDiagnosis.Alternative(label: $0.identifier, confidence: Double($0.confidence)) }

        return PestDiagnosis(
            label: best.identifier,
            confidence: Double(best.confidence),
            alternatives: alternatives
        )
    }

    private func loadModel() throws -> VNCoreMLModel {
        if let cachedModel { return cachedModel }
        guard let url = Bundle.main.url(forResource: "ClassificadorPlantas", withExtension: "mlmodelc") else {
            throw PestClassifierError.modelNotFound
        }
        let model = try VNCoreMLModel(for: MLModel(contentsOf: url, configuration: MLModelConfiguration()))
        cachedModel = model
        return model
    }
}

private extension UIImage {
    var cgOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: return .up
        case .upMirrored: return .upMirrored
        case .down: return .down
        case .downMirrored: return .downMirrored
        case .left: return .left
        case .leftMirrored: return .leftMirrored
        case .right: return .right
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    /// Para imagens que vêm de `CIImage` e não têm `cgImage` direto.
    func normalizedCGImage() -> CGImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in draw(at: .zero) }.cgImage
    }
}
