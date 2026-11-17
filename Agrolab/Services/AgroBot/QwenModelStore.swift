//
//  QwenModelStore.swift
//  Agrolab
//

import Foundation
import HuggingFace
import MLX
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

/// Guarda, baixa e carrega o modelo de linguagem do AgroBot (Qwen 3.5 4B em 4 bits, via MLX).
@MainActor
final class QwenModelStore {
    let repoID = "mlx-community/Qwen3.5-4B-4bit"
    let displayName = "Qwen 3.5 4B"
    let downloadSizeBytes: Int64 = 3_034_300_695

    private var storageDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "AgroBotModel/hub", directoryHint: .isDirectory)
    }

    var hasDownloadInProgress: Bool {
        BackgroundModelDownloader.shared.hasPendingDownload
    }

    func download(progress: @escaping @MainActor (Double) -> Void) async throws {
        try createStorageDirectory()
        guard let repo = Repo.ID(rawValue: repoID) else { throw QwenModelStoreError.notDownloaded }
        let snapshots = HubCache(cacheDirectory: storageDirectory).snapshotsDirectory(repo: repo, kind: .model)
        _ = try await BackgroundModelDownloader.shared.download(repo: repoID, into: snapshots, progress: progress)
        guard isDownloaded() else { throw QwenModelStoreError.notDownloaded }
    }

    func cancelDownload() {
        BackgroundModelDownloader.shared.cancel()
    }

    func loadContainer() async throws -> ModelContainer {
        guard let directory = downloadedModelDirectory() else {
            throw QwenModelStoreError.notDownloaded
        }
        Memory.cacheLimit = 20 * 1024 * 1024
        let configuration = ModelConfiguration(directory: directory, extraEOSTokens: ["<|im_end|>"])
        await GPUQueue.shared.acquire()
        do {
            let container = try await LLMModelFactory.shared.loadContainer(
                from: downloader(),
                using: #huggingFaceTokenizerLoader(),
                configuration: configuration
            )
            await GPUQueue.shared.release()
            return container
        } catch {
            await GPUQueue.shared.release()
            throw error
        }
    }

    func isDownloaded() -> Bool {
        downloadedModelDirectory() != nil
    }

    func delete() throws {
        cancelDownload()
        if FileManager.default.fileExists(atPath: storageDirectory.path) {
            try FileManager.default.removeItem(at: storageDirectory)
        }
    }

    private func downloader() -> any MLXLMCommon.Downloader {
        let cache = HubCache(cacheDirectory: storageDirectory)
        return #hubDownloader(HubClient(host: HubClient.defaultHost, cache: cache))
    }

    private func downloadedModelDirectory() -> URL? {
        guard let repo = Repo.ID(rawValue: repoID) else { return nil }
        let snapshots = HubCache(cacheDirectory: storageDirectory).snapshotsDirectory(repo: repo, kind: .model)
        let fm = FileManager.default
        guard let commits = try? fm.contentsOfDirectory(at: snapshots, includingPropertiesForKeys: nil) else {
            return nil
        }
        return commits.first { dir in
            let files = (try? fm.contentsOfDirectory(atPath: dir.path)) ?? []
            return files.contains("config.json")
                && files.contains("tokenizer.json")
                && Self.hasAllWeights(in: dir, files: files)
        }
    }

    private static func hasAllWeights(in directory: URL, files: [String]) -> Bool {
        let indexURL = directory.appending(path: "model.safetensors.index.json")
        guard let data = try? Data(contentsOf: indexURL) else {
            return files.contains { $0.hasSuffix(".safetensors") }
        }
        guard let index = try? JSONDecoder().decode(SafetensorsIndex.self, from: data) else {
            return false
        }
        return Set(index.weightMap.values).isSubset(of: Set(files))
    }

    private func createStorageDirectory() throws {
        var url = storageDirectory
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
    }
}

nonisolated private struct SafetensorsIndex: Decodable {
    let weightMap: [String: String]

    enum CodingKeys: String, CodingKey {
        case weightMap = "weight_map"
    }
}

nonisolated enum QwenModelStoreError: LocalizedError {
    case notDownloaded

    var errorDescription: String? {
        switch self {
        case .notDownloaded: "O AgroBot ainda não foi baixado."
        }
    }
}
