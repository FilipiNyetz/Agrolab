//
//  ProfileView.swift
//  Agrolab
//

import SwiftUI

/// Dados da conta, troca de senha, saída e central de permissões.
struct ProfileView: View {
    @Environment(SessionManager.self) private var session
    @Environment(AppContainer.self) private var container
    @Environment(\.scenePhase) private var scenePhase

    @State private var permissions = PermissionsService()
    @State private var isChangePasswordPresented = false
    @State private var isDeleteAccountPresented = false
    @State private var isSignOutConfirmationPresented = false
    @State private var isSigningOut = false

    private var user: User? { session.currentUser }

    var body: some View {
        List {
            Section {
                ProfileHeaderRow(user: user)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            Section("Dados da conta") {
                LabeledContent("Nome", value: user?.name ?? "—")
                LabeledContent("E-mail", value: user?.email ?? "—")
                LabeledContent("E-mail confirmado") {
                    if user?.emailVerified == true {
                        Label("Sim", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(AgroTheme.Colors.success)
                    } else {
                        Text("Não")
                    }
                }
            }

            Section("Segurança") {
                Button {
                    isChangePasswordPresented = true
                } label: {
                    Label("Alterar senha", systemImage: "key.fill")
                }

                Button(role: .destructive) {
                    isSignOutConfirmationPresented = true
                } label: {
                    HStack {
                        Label("Sair da conta", systemImage: "rectangle.portrait.and.arrow.right")
                        if isSigningOut {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isSigningOut)
            }

            Section {
                ForEach(PermissionKind.allCases) { kind in
                    PermissionRow(kind: kind, status: permissions.status(for: kind)) {
                        Task { await permissions.request(kind) }
                    } openSettings: {
                        permissions.openSystemSettings()
                    }
                }
            } header: {
                Text("Central de permissões")
            } footer: {
                Text("Estas são as permissões que o AgroLab pode usar. Você pode alterá-las a qualquer momento nos Ajustes do iPhone.")
            }

            Section {
                Button(role: .destructive) {
                    isDeleteAccountPresented = true
                } label: {
                    Label("Encerrar conta", systemImage: "trash")
                }
            } footer: {
                Text("O acesso é bloqueado imediatamente e seus dados são excluídos definitivamente.")
            }
        }
        .listStyle(.insetGrouped)
        .tint(AgroTheme.Colors.primaryDark)
        .scrollContentBackground(.hidden)
        .background(AgroTheme.Colors.background.ignoresSafeArea())
        .navigationTitle("Perfil")
        .navigationBarTitleDisplayMode(.inline)
        .task { await permissions.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await permissions.refresh() }
            }
        }
        .confirmationDialog("Sair da conta?", isPresented: $isSignOutConfirmationPresented, titleVisibility: .visible) {
            Button("Sair", role: .destructive) {
                isSigningOut = true
                Task { await session.signOut() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Você precisará entrar novamente para acessar suas análises.")
        }
        .sheet(isPresented: $isChangePasswordPresented) {
            ChangePasswordView(
                email: user?.email ?? "",
                viewModel: ForgotPasswordViewModel(authService: container.authService)
            )
        }
        .sheet(isPresented: $isDeleteAccountPresented) {
            DeleteAccountView()
        }
    }
}

// MARK: - Cabeçalho

private struct ProfileHeaderRow: View {
    let user: User?

    var body: some View {
        VStack(spacing: 12) {
            AvatarBadge(initials: user?.initials ?? "?", size: 84)
            Text(user?.name ?? "Produtor")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AgroTheme.Colors.textPrimary)
            Text(user?.email ?? "")
                .font(.system(size: 15))
                .foregroundStyle(AgroTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

// MARK: - Permissões

private struct PermissionRow: View {
    let kind: PermissionKind
    let status: PermissionStatus
    let request: () -> Void
    let openSettings: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: kind.symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(AgroTheme.Colors.primary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title)
                    .font(.body)
                Text(kind.purpose)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(status.label)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(statusColor)
            }

            Spacer(minLength: 8)

            trailingControl
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var statusColor: Color {
        switch status {
        case .granted: return AgroTheme.Colors.success
        case .denied, .restricted: return AgroTheme.Colors.danger
        case .notDetermined: return AgroTheme.Colors.textSecondary
        }
    }

    @ViewBuilder
    private var trailingControl: some View {
        switch status {
        case .notDetermined:
            Button("Permitir", action: request)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(AgroTheme.Colors.primary)
        case .granted:
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(AgroTheme.Colors.success)
        case .denied:
            Button("Ajustes", action: openSettings)
                .buttonStyle(.bordered)
                .controlSize(.small)
        case .restricted:
            Image(systemName: "lock.fill")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    let container = AppContainer()
    NavigationStack {
        ProfileView()
    }
    .environment(container)
    .environment(container.session)
}
