//
//  HomeViewModel.swift
//  Agrolab
//

import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
    private(set) var profileError: String?

    /// Atualiza o perfil via `GET /users/me`; erros de rede não derrubam a sessão.
    func refreshProfile(using session: SessionManager) async {
        do {
            try await session.loadProfile()
            profileError = nil
        } catch is CancellationError {
            return
        } catch let error as APIError where error.isConnectivityIssue {
            profileError = error.userMessage
        } catch {
            // Sessão rejeitada já é tratada pelo SessionManager (volta ao login).
            profileError = nil
        }
    }
}
