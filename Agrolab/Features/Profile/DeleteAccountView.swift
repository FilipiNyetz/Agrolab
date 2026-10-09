//
//  DeleteAccountView.swift
//  Agrolab
//

import SwiftUI

/// Confirmação de senha para encerrar a conta (`DELETE /users/me`).
struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionManager.self) private var session
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    InlineMessage(
                        kind: .error,
                        message: "Esta ação é definitiva. Seu acesso será bloqueado imediatamente e seus dados excluídos."
                    )

                    Text("Para confirmar, digite sua senha.")
                        .font(.system(size: 16))
                        .foregroundStyle(AgroTheme.Colors.textSecondary)

                    AgroTextField(
                        icon: "lock.fill",
                        placeholder: "Senha",
                        text: $password,
                        isSecure: true,
                        contentType: .password,
                        submitLabel: .done
                    )
                    .onChange(of: password) { errorMessage = nil }

                    if let errorMessage {
                        InlineMessage(kind: .error, message: errorMessage)
                    }

                    Button(role: .destructive) {
                        Task { await deleteAccount() }
                    } label: {
                        ZStack {
                            Text("Encerrar conta")
                                .font(.system(size: 18, weight: .semibold))
                                .opacity(isLoading ? 0 : 1)
                            if isLoading { ProgressView().tint(.white) }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(AgroTheme.Colors.danger)
                    .disabled(password.isEmpty || isLoading)
                    .padding(.top, 8)
                }
                .padding(AgroTheme.Spacing.screen)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AgroTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Encerrar conta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.disabled(isLoading)
                }
            }
        }
        .tint(AgroTheme.Colors.primaryDark)
        .animation(.easeOut(duration: 0.2), value: errorMessage)
    }

    private func deleteAccount() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await session.deleteAccount(password: password)
            dismiss()
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.agroMessage
        }
    }
}
