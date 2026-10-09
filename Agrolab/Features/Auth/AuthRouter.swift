//
//  AuthRouter.swift
//  Agrolab
//

import Foundation
import Observation

nonisolated enum AuthRoute: Hashable, Sendable {
    case login
    case register
    case verifyEmail(PendingRegistration)
    case forgotPassword
}

/// Pilha de navegação do fluxo de autenticação.
@MainActor
@Observable
final class AuthRouter {
    var path: [AuthRoute] = []

    func push(_ route: AuthRoute) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path.removeAll()
    }

    /// Vai para o login reaproveitando a tela, se já estiver na pilha.
    func showLogin() {
        if let index = path.firstIndex(of: .login) {
            path.removeSubrange(path.index(after: index)...)
        } else {
            path = [.login]
        }
    }

    /// Vai para o cadastro reaproveitando a tela, se já estiver na pilha.
    func showRegister() {
        if let index = path.firstIndex(of: .register) {
            path.removeSubrange(path.index(after: index)...)
        } else {
            path.append(.register)
        }
    }
}
