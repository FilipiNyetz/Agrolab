//
//  PestsViewModel.swift
//  Agrolab
//

import Observation
import UIKit

@Observable
final class PestsViewModel {
    private(set) var image: UIImage?
    private(set) var diagnosis: PestDiagnosis?
    private(set) var isAnalyzing = false
    var errorMessage: String?

    private let classifier = PestClassifier()

    /// Define a foto escolhida e já executa a análise.
    func analyze(_ newImage: UIImage) async {
        image = newImage
        diagnosis = nil
        errorMessage = nil
        isAnalyzing = true
        defer { isAnalyzing = false }

        do {
            diagnosis = try await classifier.classify(newImage)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reset() {
        image = nil
        diagnosis = nil
        errorMessage = nil
    }
}
