//
//  VerifyEmailViewModel.swift
//  Agrolab
//

import Foundation
import Observation

@MainActor
@Observable
final class VerifyEmailViewModel {
    static let codeLength = 6

    private(set) var pending: PendingRegistration
    var code = ""
    private(set) var now = Date.now
    private(set) var isVerifying = false
    private(set) var isResending = false
    private(set) var errorMessage: String?
    private(set) var infoMessage: String?

    private let authService: any AuthServicing
    private let session: SessionManager

    init(pending: PendingRegistration, authService: any AuthServicing, session: SessionManager) {
        self.pending = pending
        self.authService = authService
        self.session = session
    }

    // MARK: Estado derivado

    var email: String { pending.email }

    var secondsUntilExpiry: Int {
        max(0, Int(pending.expiresAt.timeIntervalSince(now).rounded(.up)))
    }

    var secondsUntilResend: Int {
        max(0, Int(pending.resendAvailableAt.timeIntervalSince(now).rounded(.up)))
    }

    var isCodeExpired: Bool { secondsUntilExpiry == 0 }
    var canResend: Bool { secondsUntilResend == 0 && !isResending && !isVerifying }
    var canVerify: Bool { code.count == Self.codeLength && !isVerifying && !isResending }

    var expiryText: String {
        isCodeExpired
            ? "O código expirou. Solicite um novo."
            : "O código expira em \(formatted(secondsUntilExpiry))"
    }

    // MARK: Relógio

    /// Mantém `now` atualizado enquanto a tela estiver visível (cancelado automaticamente pelo `.task`).
    func runClock() async {
        while !Task.isCancelled {
            now = .now
            try? await Task.sleep(for: .seconds(1))
        }
    }

    func refreshClock() {
        now = .now
    }

    // MARK: Entrada

    /// Mantém apenas dígitos e limita a seis caracteres (sempre como String, preservando zeros).
    func sanitizeCode() {
        let digits = code.filter(\.isNumber)
        let limited = String(digits.prefix(Self.codeLength))
        if limited != code { code = limited }
        if errorMessage != nil { errorMessage = nil }
    }

    // MARK: Ações

    func verify() async {
        guard canVerify else { return }
        isVerifying = true
        errorMessage = nil
        infoMessage = nil
        defer { isVerifying = false }

        do {
            let newSession = try await authService.verifyEmail(
                registrationToken: pending.registrationToken,
                code: code,
                password: pending.password
            )
            try session.signIn(with: newSession)
        } catch is CancellationError {
            return
        } catch let error as APIError where error.code == "INVALID_CODE" {
            errorMessage = "Código inválido ou expirado. Confira o e-mail ou solicite um novo código."
        } catch {
            errorMessage = error.agroMessage
        }
    }

    func resend() async {
        guard canResend else { return }
        isResending = true
        errorMessage = nil
        infoMessage = nil
        defer { isResending = false }

        let requestedAt = Date.now

        do {
            let challenge = try await authService.resendCode(registrationToken: pending.registrationToken)
            let respondedAt = Date.now
            pending = PendingRegistration(
                registrationToken: challenge.registrationToken,
                email: pending.email,
                password: pending.password,
                expiresAt: requestedAt.addingTimeInterval(TimeInterval(challenge.expiresIn)),
                resendAvailableAt: respondedAt.addingTimeInterval(TimeInterval(challenge.resendAfter))
            )
            code = ""
            infoMessage = "Enviamos um novo código para \(pending.email)."
        } catch is CancellationError {
            return
        } catch let error as APIError where error.status == 429 {
            let wait = error.retryAfter ?? 60
            pending = PendingRegistration(
                registrationToken: pending.registrationToken,
                email: pending.email,
                password: pending.password,
                expiresAt: pending.expiresAt,
                resendAvailableAt: Date.now.addingTimeInterval(wait)
            )
            errorMessage = error.agroMessage
        } catch {
            errorMessage = error.agroMessage
        }
    }

    private func formatted(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let rest = seconds % 60
        return minutes > 0 ? String(format: "%d:%02d", minutes, rest) : "\(rest) s"
    }
}
