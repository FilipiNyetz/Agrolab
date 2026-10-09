//
//  SessionManager.swift
//  Agrolab
//

import Foundation
import Observation

nonisolated enum SessionState: Equatable, Sendable {
    case restoring
    case restoreFailed(message: String)
    case signedOut
    case signedIn(User)
}

nonisolated enum SessionError: Error, LocalizedError {
    case notSignedIn
    case superseded

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Sua sessão expirou. Entre novamente."
        case .superseded: return "A sessão foi encerrada."
        }
    }
}

/// Coordena o estado da sessão: restauração ao abrir o app, renovação compartilhada
/// (uma única chamada de refresh para chamadas concorrentes), geração de sessão e logout.
@MainActor
@Observable
final class SessionManager {
    private(set) var state: SessionState = .restoring
    private(set) var currentUser: User?
    private(set) var accessToken: String?

    @ObservationIgnored private var refreshToken: String?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var refreshTask: Task<Session, Error>?

    private let authService: any AuthServicing
    private let keychain: KeychainStore

    init(authService: any AuthServicing, keychain: KeychainStore) {
        self.authService = authService
        self.keychain = keychain
    }

    var isSignedIn: Bool {
        if case .signedIn = state { return true }
        return false
    }

    // MARK: Ciclo de vida

    /// Chamado ao abrir o app: lê o refresh do Keychain e renova uma vez antes de liberar a home.
    func restoreSession() async {
        state = .restoring

        let stored: String?
        do {
            stored = try keychain.read()
        } catch {
            stored = nil
        }

        guard let stored else {
            state = .signedOut
            return
        }

        refreshToken = stored
        let currentGeneration = generation

        do {
            _ = try await refreshSession()
        } catch let error as APIError where error.isSessionRejected {
            // Já tratado dentro de refreshSession (limpa e volta ao login).
            _ = error
        } catch {
            guard currentGeneration == generation else { return }
            // Falha de rede ou indisponibilidade: mantém o token e oferece nova tentativa.
            state = .restoreFailed(message: error.agroMessage)
        }
    }

    /// Instala uma sessão nova vinda de login ou confirmação de e-mail.
    func signIn(with session: Session) throws {
        generation += 1
        refreshTask?.cancel()
        refreshTask = nil
        try install(session)
    }

    /// Encerra a sessão: limpa estado local imediatamente e revoga no servidor (melhor esforço).
    func signOut() async {
        let tokenToRevoke = refreshToken
        generation += 1
        refreshTask?.cancel()
        refreshTask = nil
        clearLocalState()
        state = .signedOut

        if let tokenToRevoke {
            try? await authService.logout(refreshToken: tokenToRevoke)
        }
    }

    /// Renovação compartilhada: chamadas concorrentes aguardam a mesma operação,
    /// que só é liberada depois de gravar o novo refresh e instalar a sessão.
    @discardableResult
    func refreshSession() async throws -> Session {
        if let task = refreshTask {
            return try await task.value
        }

        guard let token = refreshToken else {
            throw SessionError.notSignedIn
        }

        let currentGeneration = generation
        let task = Task<Session, Error> { @MainActor [authService] in
            do {
                let session = try await authService.refresh(refreshToken: token)
                guard currentGeneration == self.generation else {
                    throw SessionError.superseded
                }
                try self.install(session)
                return session
            } catch let error as APIError where error.isSessionRejected {
                if currentGeneration == self.generation {
                    self.clearLocalState()
                    self.state = .signedOut
                }
                throw error
            }
        }

        refreshTask = task
        defer {
            if refreshTask == task { refreshTask = nil }
        }
        return try await task.value
    }

    /// Executa uma operação protegida; em 401 de sessão faz uma renovação compartilhada e repete uma única vez.
    func withAccessToken<T: Sendable>(_ operation: @Sendable (String) async throws -> T) async throws -> T {
        guard let token = accessToken else { throw SessionError.notSignedIn }
        do {
            return try await operation(token)
        } catch let error as APIError where error.isUnauthorized && error.code != "INVALID_CREDENTIALS" {
            let session = try await refreshSession()
            return try await operation(session.accessToken)
        }
    }

    /// Atualiza o perfil a partir de `GET /users/me`.
    @discardableResult
    func loadProfile() async throws -> User {
        let currentGeneration = generation
        let user = try await withAccessToken { [authService] token in
            try await authService.me(accessToken: token)
        }
        // Se houve logout enquanto a chamada estava em andamento, não reinstala a sessão.
        guard currentGeneration == generation else { throw SessionError.superseded }
        currentUser = user
        state = .signedIn(user)
        return user
    }

    /// Solicita o encerramento da conta (`DELETE /users/me`) e limpa a sessão local.
    func deleteAccount(password: String) async throws {
        try await withAccessToken { [authService] token in
            try await authService.deleteAccount(accessToken: token, password: password)
        }
        generation += 1
        refreshTask?.cancel()
        refreshTask = nil
        clearLocalState()
        state = .signedOut
    }

    // MARK: Privado

    private func install(_ session: Session) throws {
        // Grava o refresh antes de liberar a navegação: sem persistência, não há login persistente.
        try keychain.save(session.refreshToken)
        refreshToken = session.refreshToken
        accessToken = session.accessToken
        currentUser = session.user
        state = .signedIn(session.user)
    }

    private func clearLocalState() {
        try? keychain.delete()
        refreshToken = nil
        accessToken = nil
        currentUser = nil
    }
}
