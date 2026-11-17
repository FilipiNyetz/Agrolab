//
//  VoiceService.swift
//  Agrolab
//

import Foundation
import Observation

/// Reconhecimento de fala (microfone → texto).
@MainActor
protocol SpeechRecognizing: AnyObject {
    func requestAuthorization() async -> Bool
    func startListening() async throws -> AsyncThrowingStream<String, Error>
    func stopListening()
}

/// Síntese de fala (texto → voz), com a voz natural opcional.
@MainActor
protocol SpeechSynthesizing: AnyObject {
    var naturalVoiceName: String { get }
    var naturalVoiceDownloadSizeBytes: Int64 { get }
    func naturalVoiceUnsupportedReason() -> String?
    func isNaturalVoiceDownloaded() -> Bool
    func downloadNaturalVoice(progress: @escaping @MainActor (Double) -> Void) async throws
    func deleteNaturalVoice() throws
    func unload()
    var lastFallbackReason: String? { get }

    func speak(_ text: String) async throws
    func stopSpeaking()
}

/// Voz do AgroBot: ouvir o produtor e ler as respostas em voz alta.
@MainActor
@Observable
final class VoiceService {
    private(set) var naturalVoiceStatus: NaturalVoiceStatus = .notDownloaded
    private(set) var isListening = false
    private(set) var speakingMessageID: UUID?
    private(set) var naturalVoiceFallbackReason: String?

    var autoSpeak: Bool {
        didSet { UserDefaults.standard.set(autoSpeak, forKey: autoSpeakKey) }
    }

    private let recognition: SpeechRecognizing
    private let synthesis: SpeechSynthesizing
    @ObservationIgnored private var downloadTask: Task<Void, Never>?
    @ObservationIgnored private var speakTask: Task<Void, Never>?
    @ObservationIgnored private let autoSpeakKey = "AgroBot.autoSpeak"

    init(recognition: SpeechRecognizing, synthesis: SpeechSynthesizing) {
        self.recognition = recognition
        self.synthesis = synthesis
        self.autoSpeak = UserDefaults.standard.bool(forKey: autoSpeakKey)
        refreshNaturalVoiceStatus()
    }

    var naturalVoiceName: String { synthesis.naturalVoiceName }
    var naturalVoiceDownloadSizeBytes: Int64 { synthesis.naturalVoiceDownloadSizeBytes }

    func listen() async throws -> AsyncThrowingStream<String, Error> {
        stopSpeaking()
        guard await recognition.requestAuthorization() else {
            throw SpeechRecognitionError.notAuthorized
        }
        let transcripts = try await recognition.startListening()
        isListening = true

        return AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                defer {
                    isListening = false
                    releaseAudioIfIdle()
                }
                do {
                    for try await transcript in transcripts {
                        continuation.yield(transcript)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func stopListening() {
        recognition.stopListening()
    }

    func speak(_ text: String, messageID: UUID, onError: @escaping (Error) -> Void) {
        stopSpeaking()
        speakingMessageID = messageID
        speakTask = Task {
            do {
                try await synthesis.speak(text)
            } catch is CancellationError {
            } catch {
                onError(error)
            }
            naturalVoiceFallbackReason = synthesis.lastFallbackReason
            guard !Task.isCancelled else { return }
            speakingMessageID = nil
            speakTask = nil
            releaseAudioIfIdle()
        }
    }

    func stopSpeaking() {
        speakTask?.cancel()
        speakTask = nil
        synthesis.stopSpeaking()
        speakingMessageID = nil
    }

    func refreshNaturalVoiceStatus() {
        guard downloadTask == nil else { return }
        if let reason = synthesis.naturalVoiceUnsupportedReason() {
            naturalVoiceStatus = .unsupported(reason: reason)
        } else {
            naturalVoiceStatus = synthesis.isNaturalVoiceDownloaded() ? .ready : .notDownloaded
        }
    }

    func startNaturalVoiceDownload() {
        guard downloadTask == nil else { return }
        naturalVoiceStatus = .downloading(progress: 0)
        let synthesis = synthesis
        downloadTask = Task { [weak self] in
            do {
                try await synthesis.downloadNaturalVoice { [weak self] progress in
                    guard let self, case .downloading = self.naturalVoiceStatus else { return }
                    self.naturalVoiceStatus = .downloading(progress: progress)
                }
                try Task.checkCancellation()
                self?.naturalVoiceStatus = .ready
            } catch {
                self?.naturalVoiceStatus = Task.isCancelled
                    ? .notDownloaded
                    : .failed(message: "Falha ao baixar a voz: \(error.localizedDescription)")
            }
            self?.downloadTask = nil
        }
    }

    func cancelNaturalVoiceDownload() {
        downloadTask?.cancel()
    }

    func deleteNaturalVoice() throws {
        stopSpeaking()
        try synthesis.deleteNaturalVoice()
        refreshNaturalVoiceStatus()
    }

    func release() {
        recognition.stopListening()
        stopSpeaking()
        synthesis.unload()
        SpeechAudioSession.deactivate()
    }

    private func releaseAudioIfIdle() {
        guard !isListening, speakTask == nil else { return }
        SpeechAudioSession.deactivate()
    }
}
