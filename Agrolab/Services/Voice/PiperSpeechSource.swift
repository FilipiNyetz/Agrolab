//
//  PiperSpeechSource.swift
//  Agrolab
//

import AVFoundation
import SherpaOnnx

/// Reproduz a voz natural (Piper, via sherpa-onnx) frase a frase.
@MainActor
final class PiperSpeechSource {
    private let tts: OfflineTTS
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat

    private let maxChunkLength = 200
    private var currentSpeech = 0

    init(tts: OfflineTTS) {
        self.tts = tts
        format = AVAudioFormat(standardFormatWithSampleRate: Double(tts.sampleRate), channels: 1)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func speak(_ text: String) async throws {
        let sentences = SpeechText.sentences(text, maxLength: maxChunkLength)
        guard !sentences.isEmpty else { return }

        currentSpeech += 1
        let speech = currentSpeech
        engine.prepare()
        try engine.start()
        player.play()
        defer { if currentSpeech == speech { stop() } }

        try await withTaskCancellationHandler {
            for (index, sentence) in sentences.enumerated() {
                let samples = await Self.synthesize(sentence, with: tts)
                guard let buffer = makeBuffer(samples) else { continue }
                try Task.checkCancellation()
                if index == sentences.count - 1 {
                    await Self.scheduleAndWait(buffer, on: player)
                } else {
                    Self.enqueue(buffer, on: player)
                }
            }
        } onCancel: {
            Task { @MainActor in
                if self.currentSpeech == speech { self.stop() }
            }
        }
    }

    func stop() {
        player.stop()
        engine.stop()
    }

    private nonisolated static func synthesize(_ sentence: String, with tts: OfflineTTS) async -> [Float] {
        tts.generate(sentence)
    }

    private func makeBuffer(_ samples: [Float]) -> AVAudioPCMBuffer? {
        guard !samples.isEmpty,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0]
        else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { channel.update(from: $0.baseAddress!, count: samples.count) }
        return buffer
    }

    private nonisolated static func enqueue(_ buffer: AVAudioPCMBuffer, on player: AVAudioPlayerNode) {
        player.scheduleBuffer(buffer, completionHandler: nil)
    }

    private nonisolated static func scheduleAndWait(_ buffer: AVAudioPCMBuffer, on player: AVAudioPlayerNode) async {
        await withCheckedContinuation { continuation in
            player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { _ in
                continuation.resume()
            }
        }
    }
}
