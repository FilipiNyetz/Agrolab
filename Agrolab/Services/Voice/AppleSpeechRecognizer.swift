//
//  AppleSpeechRecognizer.swift
//  Agrolab
//

import AVFoundation
import Speech

/// Transforma a fala do produtor em texto, sempre no aparelho (sem enviar áudio para a internet).
@MainActor
final class AppleSpeechRecognizer: SpeechRecognizing {
    private let recognizer: SFSpeechRecognizer? = {
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "pt-BR"))
        recognizer?.queue = .main
        return recognizer
    }()
    private let audioEngine = AVAudioEngine()
    private let currentRequest = RequestBox()
    private var task: SFSpeechRecognitionTask?
    private var continuation: AsyncThrowingStream<String, Error>.Continuation?

    private var committed = ""
    private var segment = ""
    private var isStopping = false
    private var restartsWithoutText = 0
    private var sessionID = UUID()
    private var segmentID = UUID()
    private static let maxRestartsWithoutText = 3

    func requestAuthorization() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speech == .authorized else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    func startListening() async throws -> AsyncThrowingStream<String, Error> {
        cancel()
        guard let recognizer, recognizer.isAvailable else {
            throw SpeechRecognitionError.unavailable
        }
        guard recognizer.supportsOnDeviceRecognition else {
            throw SpeechRecognitionError.onDeviceUnsupported
        }

        try await SpeechAudioSession.activate(.listening)

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw SpeechRecognitionError.unavailable
        }
        Self.installTap(on: input, format: format, sending: currentRequest)
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw error
        }

        let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()
        let session = UUID()
        sessionID = session
        self.continuation = continuation
        committed = ""
        segment = ""
        isStopping = false
        restartsWithoutText = 0
        startSegment(with: recognizer)
        continuation.onTermination = { [weak self] _ in
            let recognizer = self
            Task { @MainActor in
                guard let recognizer, recognizer.sessionID == session else { return }
                recognizer.cancel()
            }
        }
        return stream
    }

    func stopListening() {
        guard audioEngine.isRunning else { return }
        isStopping = true
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        currentRequest.value?.endAudio()
    }

    private func cancel() {
        stopListening()
        task?.cancel()
        task = nil
        currentRequest.value = nil
        let continuation = continuation
        self.continuation = nil
        continuation?.finish()
    }

    private func startSegment(with recognizer: SFSpeechRecognizer) {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.requiresOnDeviceRecognition = true
        currentRequest.value = request
        segment = ""
        let id = UUID()
        segmentID = id
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            MainActor.assumeIsolated {
                guard let self, self.segmentID == id else { return }
                self.handle(text: result?.bestTranscription.formattedString, isFinal: result?.isFinal ?? false, error: error)
            }
        }
    }

    private func handle(text: String?, isFinal: Bool, error: Error?) {
        guard let continuation else { return }
        if let text, !text.isEmpty {
            if segment.count > 12, text.count < segment.count / 2, !segment.hasPrefix(text) {
                commitSegment()
            }
            segment = text
            restartsWithoutText = 0
            continuation.yield(fullText)
        }
        guard isFinal || error != nil else { return }

        let heardSomething = !fullText.isEmpty
        commitSegment()
        if !isStopping, audioEngine.isRunning, heardSomething, restartsWithoutText < Self.maxRestartsWithoutText,
           let recognizer {
            restartsWithoutText += 1
            startSegment(with: recognizer)
            return
        }
        self.continuation = nil
        task = nil
        currentRequest.value = nil
        if let error, !heardSomething, !Self.isNoSpeech(error) {
            continuation.finish(throwing: error)
        } else {
            continuation.finish()
        }
    }

    private var fullText: String {
        [committed, segment].filter { !$0.isEmpty }.joined(separator: " ")
    }

    private func commitSegment() {
        committed = fullText
        segment = ""
    }

    private nonisolated static func installTap(on input: AVAudioInputNode, format: AVAudioFormat, sending box: RequestBox) {
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            box.value?.append(buffer)
        }
    }

    private nonisolated static func isNoSpeech(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == "kAFAssistantErrorDomain" && error.code == 1110
    }
}

nonisolated private final class RequestBox: @unchecked Sendable {
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?

    var value: SFSpeechAudioBufferRecognitionRequest? {
        get { lock.withLock { request } }
        set { lock.withLock { request = newValue } }
    }
}

nonisolated enum SpeechRecognitionError: LocalizedError {
    case unavailable
    case onDeviceUnsupported
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "O reconhecimento de voz não está disponível agora. Tente de novo em instantes."
        case .onDeviceUnsupported:
            "Este iPhone não consegue transformar sua fala em texto sem internet. Para sua voz não sair do aparelho, digite sua mensagem."
        case .notAuthorized:
            "Para falar com o AgroBot, permita o acesso ao microfone e ao reconhecimento de fala em Ajustes."
        }
    }
}
