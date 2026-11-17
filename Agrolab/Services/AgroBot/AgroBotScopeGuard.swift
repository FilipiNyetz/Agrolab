//
//  AgroBotScopeGuard.swift
//  Agrolab
//

import Foundation

/// Barreira determinística do escopo do AgroBot (UC06, FA01), aplicada antes e durante a geração.
/// Complementa as instruções do modelo: pedidos de código, de troca de papel ou claramente fora da
/// agricultura recebem a recusa padrão sem chegar ao modelo.
nonisolated enum AgroBotScopeGuard {
    static let refusal = "Eu sou o AgroBot e só consigo ajudar com agricultura: sua lavoura, pragas, solo, manejo e o uso do AgroLab. Quer perguntar algo sobre a sua plantação?"

    private static let codeLanguages = #"\b(python|javascript|typescript|swiftui|swift|kotlin|java|c\+\+|c#|php|ruby|golang|rust|html|css|sql|bash|shell|json|xml|react|flutter|node\.?js)\b"#
    // "sistema" e "bot" ficam de fora: "criar um sistema de irrigação" é pergunta agrícola legítima.
    private static let codeRequest = #"\b(escrev\w*|faz\w*|fac\w*|cri\w*|ger\w*|mont\w*|desenvolv\w*|codific\w*|implement\w*|corrig\w*|debug\w*|depur\w*|compil\w*)\b[^.?!]{0,40}\b(codigos?|code|scripts?|algoritmos?|funcao (em|que|para)|bugs?|programas? (em|que|para|de computador))\b|\b(cri\w*|faz\w*|fac\w*|desenvolv\w*|program\w*) (um|uma|o|meu|minha) (app|aplicativo|site|jogo|software)\b"#
    private static let codeWords = #"\b(codigo fonte|source code|linguagem de programacao|programar em|em linguagem)\b"#
    private static let jailbreak = #"\b(ignore|ignora|esqueca|esquece|desconsidere)\b[^.?!]{0,30}\b(instruc\w*|regras|prompt|orientac\w*)\b|\b(voce agora e|finja (ser|que)|aja como|atue como|modo desenvolvedor|developer mode|jailbreak|prompt do sistema|system prompt|suas instrucoes)\b"#
    private static let offTopic = #"\b(redacao|poema|poesia|letra de musica|resolva (a|esta|essa) (conta|equacao|questao)|traduz\w*|traducao)\b"#

    /// `true` quando o pedido deve ser recusado sem consultar o modelo.
    static func isOutOfScope(_ text: String) -> Bool {
        let normalized = normalize(text)
        if normalized.contains("```") { return true }
        let codeMention = matches(codeLanguages, in: normalized) || matches(codeWords, in: normalized)
        return matches(codeRequest, in: normalized)
            || (codeMention && !normalized.contains("agrolab") && !normalized.contains("agrobot"))
            || matches(jailbreak, in: normalized)
            || matches(offTopic, in: normalized)
    }

    /// `true` quando a resposta em geração começa a parecer código; a geração é interrompida.
    static func looksLikeCode(_ reply: String) -> Bool {
        if reply.contains("```") { return true }
        let lines = reply.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        let codeLines = lines.filter { line in
            line.range(of: #"^(def |func |class |import |from \w+ import|function |const |let |var |public |private |#include|print\(|console\.log|return\b|for \(|if \(|while \(|<\/?\w+>|\}|\{)"#,
                       options: .regularExpression) != nil
                || line.hasSuffix(";") || line.hasSuffix("{")
        }
        return codeLines.count >= 2
    }

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
    }

    private static func matches(_ pattern: String, in text: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }
}
