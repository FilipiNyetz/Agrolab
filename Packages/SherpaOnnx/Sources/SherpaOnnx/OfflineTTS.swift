import Foundation
import SherpaOnnxC

public final class OfflineTTS: @unchecked Sendable {
    public struct Configuration: Sendable {
        public var model: URL
        public var tokens: URL
        public var espeakData: URL
        public var numThreads: Int
        public var noiseScale: Float
        public var noiseScaleW: Float

        public init(model: URL, tokens: URL, espeakData: URL, numThreads: Int = 2,
                    noiseScale: Float = 0.667, noiseScaleW: Float = 0.8) {
            self.model = model
            self.tokens = tokens
            self.espeakData = espeakData
            self.numThreads = numThreads
            self.noiseScale = noiseScale
            self.noiseScaleW = noiseScaleW
        }
    }

    public enum Error: Swift.Error, LocalizedError {
        case couldNotLoad

        public var errorDescription: String? {
            "Não foi possível carregar a voz."
        }
    }

    private let tts: OpaquePointer
    private let lock = NSLock()

    public let sampleRate: Int

    public init(_ configuration: Configuration) throws {
        let paths: [String] = [
            configuration.model.path, configuration.tokens.path, configuration.espeakData.path, "cpu", "", "",
        ]
        let strings: [UnsafeMutablePointer<CChar>?] = paths.map { strdup($0) }
        defer { strings.forEach { free($0) } }

        var config = SherpaOnnxOfflineTtsConfig()
        config.model.vits.model = UnsafePointer(strings[0])
        config.model.vits.tokens = UnsafePointer(strings[1])
        config.model.vits.data_dir = UnsafePointer(strings[2])
        config.model.vits.lexicon = UnsafePointer(strings[4])
        config.model.vits.noise_scale = configuration.noiseScale
        config.model.vits.noise_scale_w = configuration.noiseScaleW
        config.model.vits.length_scale = 1
        config.model.num_threads = Int32(configuration.numThreads)
        config.model.debug = 0
        config.model.provider = UnsafePointer(strings[3])
        config.rule_fsts = UnsafePointer(strings[5])
        config.rule_fars = UnsafePointer(strings[5])
        config.max_num_sentences = 1
        config.silence_scale = 0.2

        guard let tts = SherpaOnnxCreateOfflineTts(&config) else { throw Error.couldNotLoad }
        self.tts = tts
        sampleRate = Int(SherpaOnnxOfflineTtsSampleRate(tts))
    }

    deinit {
        SherpaOnnxDestroyOfflineTts(tts)
    }

    public func generate(_ text: String, speed: Float = 1) -> [Float] {
        lock.lock()
        defer { lock.unlock() }
        guard let audio = SherpaOnnxOfflineTtsGenerate(tts, text, 0, speed) else { return [] }
        defer { SherpaOnnxDestroyOfflineTtsGeneratedAudio(audio) }
        let count = Int(audio.pointee.n)
        guard count > 0, let samples = audio.pointee.samples else { return [] }
        return Array(UnsafeBufferPointer(start: samples, count: count))
    }
}
