//
//  PiperSpeechSynthesizer.swift
//  Agrolab
//

import UIKit

/// Lê as respostas com a voz natural quando baixada; senão, usa a voz do iPhone.
@MainActor
final class PiperSpeechSynthesizer: SpeechSynthesizing {
    private let store = PiperVoiceStore()
    private let systemVoice = SystemSpeechSource()
    private var naturalVoiceTask: Task<PiperSpeechSource, Error>?
    private var naturalVoice: PiperSpeechSource?
    private(set) var lastFallbackReason: String?

    init() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.releaseMemory() }
        }
    }

    var naturalVoiceName: String { store.displayName }
    var naturalVoiceDownloadSizeBytes: Int64 { store.downloadSizeBytes }

    func naturalVoiceUnsupportedReason() -> String? {
        nil
    }

    func isNaturalVoiceDownloaded() -> Bool {
        store.isDownloaded()
    }

    func downloadNaturalVoice(progress: @escaping @MainActor (Double) -> Void) async throws {
        try await store.download(progress: progress)
    }

    func deleteNaturalVoice() throws {
        unload()
        try store.delete()
    }

    func unload() {
        naturalVoice?.stop()
        releaseMemory()
    }

    private func releaseMemory() {
        naturalVoice = nil
        naturalVoiceTask = nil
    }

    func speak(_ text: String) async throws {
        let text = SpeechText.clean(text)
        guard !text.isEmpty else { return }
        try await SpeechAudioSession.activate(.speaking)

        lastFallbackReason = nil
        if let voice = await loadNaturalVoice() {
            try await voice.speak(text)
        } else {
            await systemVoice.speak(text)
        }
    }

    func stopSpeaking() {
        naturalVoice?.stop()
        systemVoice.stop()
    }

    private func loadNaturalVoice() async -> PiperSpeechSource? {
        if let naturalVoice { return naturalVoice }
        guard store.isDownloaded() else { return nil }
        if naturalVoiceTask == nil {
            naturalVoiceTask = Task { [store] in
                PiperSpeechSource(tts: try await store.load())
            }
        }
        do {
            let voice = try await naturalVoiceTask?.value
            naturalVoice = voice
            return voice
        } catch {
            naturalVoiceTask = nil
            lastFallbackReason = "A última resposta foi lida com a voz do iPhone: a voz natural não carregou (\(error.localizedDescription))."
            return nil
        }
    }
}
