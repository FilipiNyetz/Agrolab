//
//  AgroBotLauncher.swift
//  Agrolab
//

import Foundation
import Observation

/// Pedido de abertura do AgroBot vindo de outra tela, já com um assunto (UC03, passo 7).
/// A `MainTabView` troca para a aba do AgroBot e a `AgroBotView` consome o assunto.
@MainActor
@Observable
final class AgroBotLauncher {
    private(set) var pendingTopic: AgroBotTopic?

    func open(_ topic: AgroBotTopic) {
        pendingTopic = topic
    }

    func takeTopic() -> AgroBotTopic? {
        defer { pendingTopic = nil }
        return pendingTopic
    }
}
