//
//  MainTabView.swift
//  Agrolab
//

import SwiftUI

/// Abas da área autenticada.
nonisolated enum AppTab: Hashable, Sendable {
    case home, soil, pests, history, agroBot
}

/// Área autenticada com a barra de abas principal.
struct MainTabView: View {
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Início", systemImage: "house", value: .home) {
                HomeView(selectedTab: $selectedTab)
            }
            Tab("Solo", systemImage: "plus.rectangle.on.rectangle", value: .soil) {
                PlaceholderFeatureView(
                    title: "Análise de Solo",
                    symbolName: "plus.rectangle.on.rectangle",
                    message: "Em breve você poderá registrar e acompanhar análises de solo por aqui."
                )
            }
            Tab("Pragas", systemImage: "ladybug", value: .pests) {
                PestsView()
            }
            Tab("Histórico", systemImage: "calendar.badge.clock", value: .history) {
                PlaceholderFeatureView(
                    title: "Histórico",
                    symbolName: "calendar.badge.clock",
                    message: "Todas as suas análises e alertas, organizados por data e talhão."
                )
            }
            Tab("AgroBot", systemImage: "cpu", value: .agroBot) {
                PlaceholderFeatureView(
                    title: "AgroBot",
                    symbolName: "cpu",
                    message: "Tire dúvidas sobre manejo, adubação e pragas com o assistente do AgroLab."
                )
            }
        }
        .tint(AgroTheme.Colors.primaryDark)
    }
}

/// Tela provisória para abas ainda não implementadas.
struct PlaceholderFeatureView: View {
    let title: String
    let symbolName: String
    let message: String

    var body: some View {
        ZStack {
            AgroTheme.Colors.background.ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: symbolName)
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(AgroTheme.Colors.primary)
                    .frame(width: 112, height: 112)
                    .background(AgroTheme.Colors.primarySoft, in: Circle())
                Text(title)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(AgroTheme.Colors.textPrimary)
                Text(message)
                    .font(.system(size: 17))
                    .foregroundStyle(AgroTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Text("Em breve")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AgroTheme.Colors.primaryDark)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AgroTheme.Colors.primarySoft, in: Capsule())
            }
        }
    }
}

#Preview {
    let container = AppContainer()
    MainTabView()
        .environment(container)
        .environment(container.session)
}
