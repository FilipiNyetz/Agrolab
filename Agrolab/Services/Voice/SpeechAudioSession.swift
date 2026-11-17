//
//  SpeechAudioSession.swift
//  Agrolab
//

import AVFoundation

/// Configura a sessão de áudio para ouvir (microfone) ou falar (leitura das respostas).
nonisolated enum SpeechAudioSession {
    enum Mode {
        case listening
        case speaking

        var category: AVAudioSession.Category {
            switch self {
            case .listening: .playAndRecord
            case .speaking: .playback
            }
        }

        var mode: AVAudioSession.Mode {
            switch self {
            case .listening: .measurement
            case .speaking: .spokenAudio
            }
        }

        var options: AVAudioSession.CategoryOptions {
            switch self {
            case .listening: [.duckOthers, .defaultToSpeaker]
            case .speaking: [.duckOthers]
            }
        }
    }

    /// `setCategory`/`setActive` podem demorar e travar a tela se rodarem na main thread.
    /// Tudo passa por esta fila serial: assim a ordem ativar → desativar é sempre respeitada.
    private static let queue = DispatchQueue(label: "SpeechAudioSession", qos: .userInitiated)

    static func activate(_ mode: Mode) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    let session = AVAudioSession.sharedInstance()
                    if session.category != mode.category || session.mode != mode.mode
                        || session.categoryOptions != mode.options {
                        try session.setCategory(mode.category, mode: mode.mode, options: mode.options)
                    }
                    try session.setActive(true)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    static func deactivate() {
        queue.async {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
