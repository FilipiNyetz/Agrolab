//
//  HomeView.swift
//  Agrolab
//

import SwiftUI

struct HomeView: View {
    @Environment(SessionManager.self) private var session
    @Binding var selectedTab: AppTab
    @State private var viewModel = HomeViewModel()
    @State private var path: [QuickAction] = []

    private var user: User? { session.currentUser }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: AgroTheme.Spacing.section) {
                    if let error = viewModel.profileError {
                        InlineMessage(kind: .info, message: error)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Analisar agora")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AgroTheme.Colors.textPrimary)

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                            ForEach(QuickAction.allCases) { action in
                                QuickActionCard(action: action) {
                                    open(action)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background {
                LinearGradient(
                    stops: [
                        .init(color: AgroTheme.Colors.backgroundAccent, location: 0),
                        .init(color: AgroTheme.Colors.background, location: 0.45),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Olá, \(user?.firstName ?? "produtor")")
            .navigationSubtitle("Bem-vindo de volta, produtor")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ProfileView()
                    } label: {
                        AvatarBadge(initials: user?.initials ?? "?", size: 34)
                    }
                    .accessibilityLabel("Perfil")
                }
            }
            .navigationDestination(for: QuickAction.self) { action in
                PlaceholderFeatureView(
                    title: action.title,
                    symbolName: action.symbolName,
                    message: action.detailDescription
                )
                .navigationTitle(action.title)
                .navigationBarTitleDisplayMode(.inline)
            }
            .refreshable { await viewModel.refreshProfile(using: session) }
            .task { await viewModel.refreshProfile(using: session) }
        }
        .tint(AgroTheme.Colors.primaryDark)
    }

    /// Leva para a aba da funcionalidade; sem aba própria, empilha a tela dentro da home.
    private func open(_ action: QuickAction) {
        if let tab = action.tab {
            selectedTab = tab
        } else {
            path.append(action)
        }
    }
}

private struct QuickActionCard: View {
    let action: QuickAction
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: action.symbolName)
                    .font(.system(size: 34, weight: .regular))
                    .foregroundStyle(AgroTheme.Colors.primaryDark)
                    .frame(height: 40)
                Text(action.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AgroTheme.Colors.primaryDark)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 108)
            .background(AgroTheme.Colors.surface, in: RoundedRectangle(cornerRadius: AgroTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AgroTheme.Radius.card, style: .continuous)
                    .strokeBorder(AgroTheme.Colors.primary.opacity(0.8), lineWidth: 1.5)
            }
            .shadow(color: AgroTheme.Colors.forest.opacity(0.06), radius: 10, y: 4)
        }
        .buttonStyle(AgroPressStyle())
    }
}

#Preview {
    @Previewable @State var tab: AppTab = .home
    let container = AppContainer()
    HomeView(selectedTab: $tab)
        .environment(container)
        .environment(container.session)
}
