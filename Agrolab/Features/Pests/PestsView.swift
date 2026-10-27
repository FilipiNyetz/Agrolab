//
//  PestsView.swift
//  Agrolab
//

import PhotosUI
import SwiftUI

/// Identificação de pragas e doenças a partir de uma foto, usando Core ML.
struct PestsView: View {
    @State private var viewModel = PestsViewModel()
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    photoArea
                    actions

                    if viewModel.isAnalyzing {
                        ProgressView("Analisando…")
                            .frame(maxWidth: .infinity)
                            .tint(AgroTheme.Colors.primaryDark)
                    }
                    if let message = viewModel.errorMessage {
                        InlineMessage(kind: .error, message: message)
                    }
                    if let diagnosis = viewModel.diagnosis {
                        DiagnosisCard(diagnosis: diagnosis)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background {
                LinearGradient(
                    stops: [
                        .init(color: AgroTheme.Colors.backgroundAccent, location: 0),
                        .init(color: AgroTheme.Colors.background, location: 0.45),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
            .navigationTitle("Identificar Pragas")
            .navigationSubtitle("Fotografe uma folha da planta")
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await viewModel.analyze(image)
                    } else {
                        viewModel.errorMessage = "Não foi possível carregar a foto escolhida."
                    }
                    pickerItem = nil
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    Task { await viewModel.analyze(image) }
                }
                .ignoresSafeArea()
            }
        }
        .tint(AgroTheme.Colors.primaryDark)
    }

    private var photoArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AgroTheme.Radius.card, style: .continuous)
                .fill(AgroTheme.Colors.surface)
            if let image = viewModel.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: AgroTheme.Radius.card, style: .continuous))
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(AgroTheme.Colors.primary)
                    Text("Tire ou escolha uma foto nítida de uma folha, com boa iluminação. O app identifica doenças em 14 culturas.")
                        .font(.system(size: 15))
                        .foregroundStyle(AgroTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
        }
        .frame(height: 280)
        .overlay {
            RoundedRectangle(cornerRadius: AgroTheme.Radius.card, style: .continuous)
                .strokeBorder(AgroTheme.Colors.primary.opacity(0.8), lineWidth: 1.5)
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            if CameraPicker.isAvailable {
                AgroPrimaryButton(title: "Tirar foto") { showCamera = true }
            }
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Text("Escolher da galeria")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AgroTheme.Colors.primaryDark)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(AgroTheme.Colors.surface, in: RoundedRectangle(cornerRadius: AgroTheme.Radius.button, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AgroTheme.Radius.button, style: .continuous)
                            .strokeBorder(AgroTheme.Colors.primary, lineWidth: 1.5)
                    }
            }
            .buttonStyle(AgroPressStyle())
            .disabled(viewModel.isAnalyzing)
        }
    }
}

private struct DiagnosisCard: View {
    let diagnosis: PestDiagnosis

    private var tint: Color {
        if !diagnosis.isConclusive { return AgroTheme.Colors.caution }
        return diagnosis.isHealthy ? AgroTheme.Colors.success : AgroTheme.Colors.warning
    }

    private var background: Color {
        if !diagnosis.isConclusive { return AgroTheme.Colors.cautionSoft }
        return diagnosis.isHealthy ? AgroTheme.Colors.successSoft : AgroTheme.Colors.warningSoft
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(diagnosis.isConclusive ? diagnosis.title : "Resultado inconclusivo")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(tint)
                Spacer()
                Text(diagnosis.confidence, format: .percent.precision(.fractionLength(0)))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(tint)
            }

            Text(diagnosis.isConclusive
                 ? diagnosis.recommendation
                 : "A confiança do modelo está baixa (provável: \(diagnosis.title)). Tente outra foto, mais nítida e próxima da folha, e confira se a folha está bem enquadrada.")
                .font(.system(size: 16))
                .foregroundStyle(AgroTheme.Colors.textPrimary)

            if !diagnosis.alternatives.isEmpty {
                Divider()
                Text("Outras possibilidades")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AgroTheme.Colors.textSecondary)
                ForEach(diagnosis.alternatives.prefix(3)) { alternative in
                    HStack {
                        Text(PestDiagnosis.displayName(for: alternative.label))
                        Spacer()
                        Text(alternative.confidence, format: .percent.precision(.fractionLength(0)))
                    }
                    .font(.system(size: 15))
                    .foregroundStyle(AgroTheme.Colors.textSecondary)
                }
            }

            Text("Resultado indicativo, gerado por um modelo de IA. Não substitui a avaliação de um engenheiro agrônomo.")
                .font(.system(size: 12))
                .foregroundStyle(AgroTheme.Colors.textSecondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background, in: RoundedRectangle(cornerRadius: AgroTheme.Radius.card, style: .continuous))
    }
}

#Preview {
    PestsView()
}
