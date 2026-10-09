//
//  AppEnvironment.swift
//  Agrolab
//

import Foundation

/// Configuração de ambiente (base da API, versão da política de privacidade, timeouts).
nonisolated struct AppEnvironment: Sendable {
    let apiBaseURL: URL
    let privacyPolicyVersion: String
    let requestTimeout: TimeInterval

    static let production = AppEnvironment(
        apiBaseURL: URL(string: "https://api-agrolab.jamesmarcos.com/api/v1")!,
        privacyPolicyVersion: "2026-10-06",
        requestTimeout: 20
    )

    /// Ambiente ativo. Trocar aqui para apontar para um backend local, se necessário.
    static var current: AppEnvironment { .production }
}
