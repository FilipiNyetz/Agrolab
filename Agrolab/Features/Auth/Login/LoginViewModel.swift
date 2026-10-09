//
//  LoginViewModel.swift
//  Agrolab
//

import Foundation
import Observation

@MainActor
@Observable
final class LoginViewModel {
    var email = ""
    var password = ""
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let authService: any AuthServicing
    private let session: SessionManager

    init(authService: any AuthServicing, session: SessionManager) {
        self.authService = authService
        self.session = session
    }

    var canSubmit: Bool {
        !normalizedEmail.isEmpty && !password.isEmpty && !isLoading
    }

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func clearError() {
        errorMessage = nil
    }

    func submit() async {
        guard canSubmit else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // A senha não recebe trim nem qualquer transformação.
            let newSession = try await authService.login(email: normalizedEmail, password: password)
            try session.signIn(with: newSession)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.agroMessage
        }
    }
}
