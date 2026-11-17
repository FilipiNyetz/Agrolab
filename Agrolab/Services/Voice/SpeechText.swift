//
//  SpeechText.swift
//  Agrolab
//

import Foundation

/// Limpa o texto para leitura em voz alta e o divide em frases curtas.
nonisolated enum SpeechText {
    static func clean(_ text: String) -> String {
        var result = text
        result = replacing("```[\\s\\S]*?```", in: result, with: " ")
        result = replacing("\\[([^\\]]+)\\]\\([^)]+\\)", in: result, with: "$1")
        result = replacing("(?m)^\\s*([-*•]|\\d+\\.)\\s+", in: result, with: "")
        result = replacing("[*_`#>|]+", in: result, with: "")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func sentences(_ text: String, maxLength: Int = 220) -> [String] {
        var result: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) { sentence, _, _, _ in
            guard let sentence = sentence?.trimmingCharacters(in: .whitespacesAndNewlines), !sentence.isEmpty else { return }
            result += split(sentence, maxLength: maxLength)
        }
        return result
    }

    private static func split(_ sentence: String, maxLength: Int) -> [String] {
        guard sentence.count > maxLength else { return [sentence] }
        let clauses = self.clauses(sentence).flatMap { splitWords($0, maxLength: maxLength) }
        return merge(clauses, separator: " ", maxLength: maxLength)
    }

    private static func clauses(_ sentence: String) -> [String] {
        var result: [String] = []
        var current = ""
        for character in sentence {
            if character == " ", let last = current.last, ",;:".contains(last) {
                result.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    private static func splitWords(_ clause: String, maxLength: Int) -> [String] {
        guard clause.count > maxLength else { return [clause] }
        return merge(clause.split(separator: " ").map(String.init), separator: " ", maxLength: maxLength)
    }

    private static func merge(_ pieces: [String], separator: String, maxLength: Int) -> [String] {
        var parts: [String] = []
        var current = ""
        for piece in pieces {
            if !current.isEmpty, current.count + separator.count + piece.count > maxLength {
                parts.append(current)
                current = ""
            }
            current += current.isEmpty ? piece : separator + piece
        }
        if !current.isEmpty { parts.append(current) }
        return parts
    }

    private static func replacing(_ pattern: String, in text: String, with template: String) -> String {
        text.replacingOccurrences(of: pattern, with: template, options: .regularExpression)
    }
}
