//
//  AppContainer.swift
//  Agrolab
//

import Foundation
import Observation

/// Composição das dependências do app (serviços e sessão).
@MainActor
@Observable
final class AppContainer {
    let environment: AppEnvironment
    let authService: any AuthServicing
    let session: SessionManager

    init(environment: AppEnvironment = .current) {
        self.environment = environment

        let client = APIClient(baseURL: environment.apiBaseURL, timeout: environment.requestTimeout)
        let authService = AuthService(client: client, privacyPolicyVersion: environment.privacyPolicyVersion)
        let keychain = KeychainStore(service: "br.com.Agrolab.auth", account: "refresh_token")

        self.authService = authService
        self.session = SessionManager(authService: authService, keychain: keychain)
    }
}
