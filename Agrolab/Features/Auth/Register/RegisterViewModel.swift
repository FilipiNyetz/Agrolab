//
//  RegisterViewModel.swift
//  Agrolab
//

import Foundation
import Observation

@MainActor
@Observable
final class RegisterViewModel {
    var name = ""
    var email = ""
    var password = ""
    var confirmPassword = ""
    var acceptedTerms = false

    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let authService: any AuthServicing

    init(authService: any AuthServicing) {
        self.authService = authService
    }

    // MARK: Regras de formulário

    static let minimumPasswordLength = 12
    static let maximumPasswordBytes = 72

    private var normalizedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var normalizedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Python conta pontos Unicode; `unicodeScalars` aproxima essa regra.
    var isPasswordLongEnough: Bool {
        password.unicodeScalars.count >= Self.minimumPasswordLength
    }

    var isPasswordWithinLimit: Bool {
        password.utf8.count <= Self.maximumPasswordBytes
    }

    var passwordsMatch: Bool {
        !confirmPassword.isEmpty && password == confirmPassword
    }

    var isNameValid: Bool {
        !normalizedName.isEmpty && normalizedName.count <= 120
    }

    var isEmailValid: Bool {
        let value = normalizedEmail
        guard let at = value.firstIndex(of: "@"), at != value.startIndex else { return false }
        let domain = value[value.index(after: at)...]
        return domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".")
    }

    var canSubmit: Bool {
        isNameValid && isEmailValid && isPasswordLongEnough && isPasswordWithinLimit
            && passwordsMatch && acceptedTerms && !isLoading
    }

    /// Dica contextual mostrada abaixo do campo de senha.
    var passwordHint: String {
        if password.isEmpty { return "Mínimo de \(Self.minimumPasswordLength) caracteres" }
        if !isPasswordWithinLimit { return "A senha é longa demais (máximo de 72 bytes)" }
        if !isPasswordLongEnough {
            let remaining = Self.minimumPasswordLength - password.unicodeScalars.count
            return "Faltam \(remaining) caractere\(remaining == 1 ? "" : "s")"
        }
        return "Senha forte o suficiente"
    }

    func clearError() {
        errorMessage = nil
    }

    // MARK: Ação

    /// Envia o cadastro e devolve os dados pendentes para a tela de verificação.
    func submit() async -> PendingRegistration? {
        guard canSubmit else { return nil }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Marca o início da requisição para um contador conservador de expiração.
        let requestedAt = Date.now

        do {
            let challenge = try await authService.register(
                name: normalizedName,
                email: normalizedEmail,
                password: password
            )
            let respondedAt = Date.now
            return PendingRegistration(
                registrationToken: challenge.registrationToken,
                email: normalizedEmail,
                password: password,
                expiresAt: requestedAt.addingTimeInterval(TimeInterval(challenge.expiresIn)),
                resendAvailableAt: respondedAt.addingTimeInterval(TimeInterval(challenge.resendAfter))
            )
        } catch is CancellationError {
            return nil
        } catch let error as APIError where error.code == "POLICY_VERSION_INVALID" {
            errorMessage = "A versão dos termos deste app está desatualizada. Atualize o aplicativo para continuar."
            return nil
        } catch {
            errorMessage = error.agroMessage
            return nil
        }
    }
}
