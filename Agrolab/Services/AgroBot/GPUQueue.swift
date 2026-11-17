//
//  GPUQueue.swift
//  Agrolab
//

import Foundation

/// Fila que garante um único uso da GPU por vez (carregar o modelo ou gerar resposta).
actor GPUQueue {
    static let shared = GPUQueue()

    private var busy = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        guard busy else {
            busy = true
            return
        }
        await withCheckedContinuation { waiting.append($0) }
    }

    func release() {
        if waiting.isEmpty {
            busy = false
        } else {
            waiting.removeFirst().resume()
        }
    }
}
