//
//  PiperVoiceStore.swift
//  Agrolab
//

import Foundation
import HuggingFace
import SherpaOnnx

/// Baixa e carrega a voz natural brasileira (Piper "Faber") do Hugging Face.
@MainActor
final class PiperVoiceStore {
    let displayName = "Faber (pt-BR)"
    let downloadSizeBytes: Int64 = 63_917_690

    private let repoID = "csukuangfj/vits-piper-pt_BR-faber-medium"
    private let modelFile = "pt_BR-faber-medium.onnx"
    private let tokensFile = "tokens.txt"
    private let espeakFiles = [
        "espeak-ng-data/phontab", "espeak-ng-data/phonindex", "espeak-ng-data/phondata",
        "espeak-ng-data/intonations", "espeak-ng-data/pt_dict",
        "espeak-ng-data/lang/roa/pt", "espeak-ng-data/lang/roa/pt-BR",
    ]
    private var files: [String] { [modelFile, tokensFile] + espeakFiles }

    private let numThreads = 1

    private var storageDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "PiperVoice", directoryHint: .isDirectory)
    }
    private var cache: HubCache {
        HubCache(cacheDirectory: storageDirectory.appending(path: "hub", directoryHint: .isDirectory))
    }

    func download(progress: @escaping @MainActor (Double) -> Void) async throws {
        try createStorageDirectory()
        let client = HubClient(host: HubClient.defaultHost, cache: cache)
        guard let repo = Repo.ID(rawValue: repoID) else { throw PiperVoiceStoreError.notDownloaded }
        _ = try await client.downloadSnapshot(of: repo, matching: files) { snapshotProgress in
            progress(snapshotProgress.fractionCompleted)
        }
    }

    func isDownloaded() -> Bool {
        voiceDirectory() != nil
    }

    func load() async throws -> OfflineTTS {
        guard let directory = voiceDirectory() else { throw PiperVoiceStoreError.notDownloaded }
        let configuration = OfflineTTS.Configuration(
            model: directory.appending(path: modelFile),
            tokens: directory.appending(path: tokensFile),
            espeakData: directory.appending(path: "espeak-ng-data", directoryHint: .isDirectory),
            numThreads: numThreads
        )
        return try await Self.load(configuration)
    }

    private nonisolated static func load(_ configuration: OfflineTTS.Configuration) async throws -> OfflineTTS {
        try OfflineTTS(configuration)
    }

    func delete() throws {
        if FileManager.default.fileExists(atPath: storageDirectory.path) {
            try FileManager.default.removeItem(at: storageDirectory)
        }
    }


    private func voiceDirectory() -> URL? {
        guard let repo = Repo.ID(rawValue: repoID) else { return nil }
        let snapshots = cache.snapshotsDirectory(repo: repo, kind: .model)
        let fm = FileManager.default
        guard let commits = try? fm.contentsOfDirectory(at: snapshots, includingPropertiesForKeys: nil) else {
            return nil
        }
        return commits.first { dir in
            files.allSatisfy { fm.fileExists(atPath: dir.appending(path: $0).path) }
        }
    }

    private func createStorageDirectory() throws {
        var url = storageDirectory
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
    }
}

nonisolated enum PiperVoiceStoreError: LocalizedError {
    case notDownloaded

    var errorDescription: String? {
        switch self {
        case .notDownloaded: "A voz natural ainda não foi baixada."
        }
    }
}
