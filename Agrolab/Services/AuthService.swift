//
//  AuthService.swift
//  Agrolab
//

import Foundation

/// Contrato das operações de autenticação (facilita mocks em testes/previews).
nonisolated protocol AuthServicing: Sendable {
    func register(name: String, email: String, password: String) async throws -> RegistrationChallenge
    func verifyEmail(registrationToken: String, code: String, password: String) async throws -> Session
    func resendCode(registrationToken: String) async throws -> RegistrationChallenge
    func login(email: String, password: String) async throws -> Session
    func refresh(refreshToken: String) async throws -> Session
    func logout(refreshToken: String) async throws
    func me(accessToken: String) async throws -> User
    func forgotPassword(email: String) async throws
    func resetPassword(resetToken: String, newPassword: String) async throws
    func deleteAccount(accessToken: String, password: String) async throws
}

/// Implementação real contra a API AgroLab (`/api/v1`).
nonisolated struct AuthService: AuthServicing {
    let client: APIClient
    let privacyPolicyVersion: String

    // MARK: Corpos de requisição (snake_case explícito; a API rejeita campos extras)

    private struct RegisterBody: Encodable, Sendable {
        let name: String
        let email: String
        let password: String
        let acceptedTerms: Bool
        let privacyPolicyVersion: String

        enum CodingKeys: String, CodingKey {
            case name, email, password
            case acceptedTerms = "accepted_terms"
            case privacyPolicyVersion = "privacy_policy_version"
        }
    }

    private struct VerifyBody: Encodable, Sendable {
        let registrationToken: String
        let code: String
        let password: String

        enum CodingKeys: String, CodingKey {
            case code, password
            case registrationToken = "registration_token"
        }
    }

    private struct RegistrationTokenBody: Encodable, Sendable {
        let registrationToken: String
        enum CodingKeys: String, CodingKey { case registrationToken = "registration_token" }
    }

    private struct LoginBody: Encodable, Sendable {
        let email: String
        let password: String
    }

    private struct RefreshTokenBody: Encodable, Sendable {
        let refreshToken: String
        enum CodingKeys: String, CodingKey { case refreshToken = "refresh_token" }
    }

    private struct EmailBody: Encodable, Sendable {
        let email: String
    }

    private struct ResetBody: Encodable, Sendable {
        let resetToken: String
        let newPassword: String

        enum CodingKeys: String, CodingKey {
            case resetToken = "reset_token"
            case newPassword = "new_password"
        }
    }

    private struct PasswordBody: Encodable, Sendable {
        let password: String
    }

    // MARK: Operações

    func register(name: String, email: String, password: String) async throws -> RegistrationChallenge {
        let body = RegisterBody(
            name: name,
            email: email,
            password: password,
            acceptedTerms: true,
            privacyPolicyVersion: privacyPolicyVersion
        )
        return try await client.send(APIRequest(.post, "auth/register", body: body))
    }

    func verifyEmail(registrationToken: String, code: String, password: String) async throws -> Session {
        let body = VerifyBody(registrationToken: registrationToken, code: code, password: password)
        return try await client.send(APIRequest(.post, "auth/verify-email", body: body))
    }

    func resendCode(registrationToken: String) async throws -> RegistrationChallenge {
        let body = RegistrationTokenBody(registrationToken: registrationToken)
        return try await client.send(APIRequest(.post, "auth/resend-code", body: body))
    }

    func login(email: String, password: String) async throws -> Session {
        let body = LoginBody(email: email, password: password)
        return try await client.send(APIRequest(.post, "auth/login", body: body))
    }

    func refresh(refreshToken: String) async throws -> Session {
        let body = RefreshTokenBody(refreshToken: refreshToken)
        return try await client.send(APIRequest(.post, "auth/refresh", body: body))
    }

    func logout(refreshToken: String) async throws {
        let body = RefreshTokenBody(refreshToken: refreshToken)
        try await client.send(APIRequest(.post, "auth/logout", body: body))
    }

    func me(accessToken: String) async throws -> User {
        try await client.send(APIRequest(.get, "users/me", accessToken: accessToken))
    }

    func forgotPassword(email: String) async throws {
        try await client.send(APIRequest(.post, "auth/forgot-password", body: EmailBody(email: email)))
    }

    func resetPassword(resetToken: String, newPassword: String) async throws {
        let body = ResetBody(resetToken: resetToken, newPassword: newPassword)
        try await client.send(APIRequest(.post, "auth/reset-password", body: body))
    }

    func deleteAccount(accessToken: String, password: String) async throws {
        let body = PasswordBody(password: password)
        try await client.send(APIRequest(.delete, "users/me", body: body, accessToken: accessToken))
    }
}
