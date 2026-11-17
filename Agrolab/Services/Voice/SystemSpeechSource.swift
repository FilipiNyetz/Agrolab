//
//  SystemSpeechSource.swift
//  Agrolab
//

import AVFoundation

/// Voz do próprio iPhone (AVSpeechSynthesizer), usada quando a voz natural não está baixada.
@MainActor
final class SystemSpeechSource: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var current: (utterance: ObjectIdentifier, continuation: CheckedContinuation<Void, Never>)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) async {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.bestVoice()
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                current = (ObjectIdentifier(utterance), continuation)
                synthesizer.speak(utterance)
            }
        } onCancel: {
            Task { @MainActor in self.stop() }
        }
    }

    func stop() {
        finish(current?.utterance)
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func finish(_ utterance: ObjectIdentifier?) {
        guard let current, current.utterance == utterance else { return }
        self.current = nil
        current.continuation.resume()
    }

    private static func bestVoice() -> AVSpeechSynthesisVoice? {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "pt-BR" }
            .max { $0.quality.rawValue < $1.quality.rawValue }
            ?? AVSpeechSynthesisVoice(language: "pt-BR")
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.finish(id) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.finish(id) }
    }
}
