//
//  ForgotPasswordViewModel.swift
//  Agrolab
//

import Foundation
import Observation

@MainActor
@Observable
final class ForgotPasswordViewModel {
    enum Step: Equatable {
        case requestEmail
        case resetPassword
        case done
    }

    private(set) var step: Step = .requestEmail
    var email = ""
    var resetToken = ""
    var newPassword = ""
    var confirmPassword = ""

    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var infoMessage: String?

    private let authService: any AuthServicing

    init(authService: any AuthServicing) {
        self.authService = authService
    }

    private var normalizedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var normalizedToken: String { resetToken.trimmingCharacters(in: .whitespacesAndNewlines) }

    var canRequest: Bool {
        normalizedEmail.contains("@") && !isLoading
    }

    var isPasswordValid: Bool {
        newPassword.unicodeScalars.count >= RegisterViewModel.minimumPasswordLength
            && newPassword.utf8.count <= RegisterViewModel.maximumPasswordBytes
    }

    var passwordsMatch: Bool {
        !confirmPassword.isEmpty && newPassword == confirmPassword
    }

    var canReset: Bool {
        normalizedToken.count >= 8 && isPasswordValid && passwordsMatch && !isLoading
    }

    func clearError() {
        errorMessage = nil
    }

    /// Permite ir direto para a etapa do token (quem já recebeu o e-mail).
    func skipToReset() {
        errorMessage = nil
        step = .resetPassword
    }

    func requestReset() async {
        guard canRequest else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await authService.forgotPassword(email: normalizedEmail)
            infoMessage = "Se \(normalizedEmail) estiver cadastrado, você receberá um e-mail com o código de recuperação. Ele vale por 15 minutos."
            step = .resetPassword
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.agroMessage
        }
    }

    func reset() async {
        guard canReset else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await authService.resetPassword(resetToken: normalizedToken, newPassword: newPassword)
            newPassword = ""
            confirmPassword = ""
            resetToken = ""
            step = .done
        } catch is CancellationError {
            return
        } catch let error as APIError where error.status == 400 {
            errorMessage = "Código de recuperação inválido, expirado ou já utilizado. Solicite um novo."
        } catch {
            errorMessage = error.agroMessage
        }
    }
}
