//
//  AuthModels.swift
//  Agrolab
//

import Foundation

/// Usuário autenticado (retornado em `user` no login/verify/refresh e diretamente em `GET /users/me`).
nonisolated struct User: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let name: String
    let email: String
    let emailVerified: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, email
        case emailVerified = "email_verified"
    }

    var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map { String($0).uppercased() }
        return letters.isEmpty ? "?" : letters.joined()
    }
}

/// Sessão retornada por login, confirmação de e-mail e refresh.
nonisolated struct Session: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
    let user: User

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case user
    }
}

/// Desafio de cadastro pendente (202 em register/resend-code).
nonisolated struct RegistrationChallenge: Decodable, Sendable {
    let registrationToken: String
    let expiresIn: Int
    let resendAfter: Int

    enum CodingKeys: String, CodingKey {
        case registrationToken = "registration_token"
        case expiresIn = "expires_in"
        case resendAfter = "resend_after"
    }
}

/// Dados mantidos apenas em memória enquanto o usuário confirma o e-mail.
nonisolated struct PendingRegistration: Hashable, Sendable {
    let registrationToken: String
    let email: String
    let password: String
    let expiresAt: Date
    let resendAvailableAt: Date
}
