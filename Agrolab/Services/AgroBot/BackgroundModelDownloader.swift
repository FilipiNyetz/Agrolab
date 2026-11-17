//
//  BackgroundModelDownloader.swift
//  Agrolab
//

import Foundation

/// Baixa os arquivos do modelo do AgroBot (Hugging Face) numa URLSession em segundo plano, com retomada.
nonisolated final class BackgroundModelDownloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    static let shared = BackgroundModelDownloader()
    static let sessionIdentifier = (Bundle.main.bundleIdentifier ?? "br.com.Agrolab") + ".agrobot-model"

    struct Plan: Codable, Equatable {
        let repo: String
        let revision: String
        let directory: String
        let files: [String: Int64]

        var totalBytes: Int64 { files.values.reduce(0, +) }
    }

    private static let planKey = "AgroBot.backgroundDownloadPlan"
    private static let maxRetries = 8
    private static let host = URL(string: "https://huggingface.co")!

    private let lock = NSLock()
    private var plan: Plan?
    private var bytesWritten: [String: Int64] = [:]
    private var retries: [String: Int] = [:]
    private var progressHandler: (@MainActor (Double) -> Void)?
    private var continuation: CheckedContinuation<Void, Error>?
    private var isCancelled = false
    private var backgroundCompletion: (() -> Void)?

    /// Criada no `init` (o singleton é criado uma única vez), reconectando-se à sessão em segundo plano.
    private var session: URLSession!

    private override init() {
        super.init()
        plan = Self.savedPlan
        let configuration = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        configuration.isDiscretionary = false
        configuration.sessionSendsLaunchEvents = true
        configuration.allowsCellularAccess = true
        configuration.timeoutIntervalForResource = 60 * 60 * 24
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    var hasPendingDownload: Bool {
        lock.withLock { plan != nil }
    }

    func reconnect() {
        _ = session
    }

    func handleBackgroundEvents(completion: @escaping () -> Void) {
        lock.withLock { backgroundCompletion = completion }
        reconnect()
    }

    func download(repo: String, into snapshots: URL, progress: @escaping @MainActor (Double) -> Void) async throws -> URL {
        let plan = try await currentPlan(repo: repo, snapshots: snapshots)
        let directory = Self.url(forStoredPath: plan.directory)
        let missing = plan.files.filter { !Self.isComplete(directory.appending(path: $0.key), size: $0.value) }

        guard !missing.isEmpty else {
            finish()
            return directory
        }

        let running = await session.allTasks
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                lock.withLock {
                    self.continuation = continuation
                    self.progressHandler = progress
                    self.isCancelled = false
                    self.bytesWritten = [:]
                    self.retries = [:]
                }
                let active = Set(running.filter { $0.state == .running || $0.state == .suspended }.compactMap(\.taskDescription))
                for (path, size) in missing where !active.contains(path) {
                    start(path: path, size: size, plan: plan)
                }
                running.filter { $0.state == .suspended }.forEach { $0.resume() }
                reportProgress()
                resumeIfComplete()
            }
        } onCancel: {
            cancel()
        }
        finish()
        return directory
    }

    func cancel() {
        let continuation = lock.withLock {
            isCancelled = true
            defer { self.continuation = nil }
            return self.continuation
        }
        session.getAllTasks { $0.forEach { $0.cancel() } }
        clearPlan()
        continuation?.resume(throwing: CancellationError())
    }

    // MARK: - Plano (quais arquivos baixar)

    private func currentPlan(repo: String, snapshots: URL) async throws -> Plan {
        if let saved = lock.withLock({ plan }), saved.repo == repo,
           FileManager.default.fileExists(atPath: Self.url(forStoredPath: saved.directory).path) {
            return saved
        }
        let info = try await Self.fetchRepoInfo(repo)
        let directory = snapshots.appending(path: info.sha, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let files = Dictionary(info.siblings
            .filter { !$0.rfilename.hasPrefix(".") && $0.rfilename != "README.md" }
            .map { ($0.rfilename, $0.size ?? 0) }) { first, _ in first }
        let plan = Plan(repo: repo, revision: info.sha, directory: Self.storedPath(for: directory), files: files)
        lock.withLock { self.plan = plan }
        if let data = try? JSONEncoder().encode(plan) {
            UserDefaults.standard.set(data, forKey: Self.planKey)
        }
        return plan
    }

    private struct RepoInfo: Decodable {
        struct Sibling: Decodable {
            let rfilename: String
            let size: Int64?
        }
        let sha: String
        let siblings: [Sibling]
    }

    private static func fetchRepoInfo(_ repo: String) async throws -> RepoInfo {
        var components = URLComponents(url: host.appending(path: "api/models/\(repo)/revision/main"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "blobs", value: "true")]
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw BackgroundModelDownloaderError.unavailable }
        return try JSONDecoder().decode(RepoInfo.self, from: data)
    }

    private func start(path: String, size: Int64, plan: Plan, resumeData: Data? = nil) {
        let task: URLSessionDownloadTask
        if let resumeData {
            task = session.downloadTask(withResumeData: resumeData)
        } else {
            let url = Self.host.appending(path: "\(plan.repo)/resolve/\(plan.revision)/\(path)")
            task = session.downloadTask(with: url)
        }
        task.taskDescription = path
        task.countOfBytesClientExpectsToReceive = size
        task.resume()
    }

    private func finish() {
        lock.withLock {
            progressHandler = nil
            continuation = nil
        }
        clearPlan()
    }

    private func clearPlan() {
        lock.withLock {
            plan = nil
            bytesWritten = [:]
        }
        UserDefaults.standard.removeObject(forKey: Self.planKey)
    }

    // MARK: - URLSessionDownloadDelegate

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let path = downloadTask.taskDescription, let plan = lock.withLock({ plan }),
              (downloadTask.response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true else { return }
        let destination = Self.url(forStoredPath: plan.directory).appending(path: path)
        do {
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: location, to: destination)
        } catch {
            return
        }
        lock.withLock { bytesWritten[path] = plan.files[path] ?? 0 }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let path = downloadTask.taskDescription else { return }
        lock.withLock { self.bytesWritten[path] = totalBytesWritten }
        reportProgress()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let path = task.taskDescription, let plan = lock.withLock({ plan }) else { return }

        if let error, !lock.withLock({ isCancelled }) {
            let attempt = lock.withLock { () -> Int in
                retries[path, default: 0] += 1
                return retries[path] ?? 0
            }
            guard attempt <= Self.maxRetries else {
                fail(error)
                return
            }
            let resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data
            let delay = min(Double(attempt) * 2, 30)
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.start(path: path, size: plan.files[path] ?? 0, plan: plan, resumeData: resumeData)
            }
            return
        }

        if error == nil, let status = (task.response as? HTTPURLResponse)?.statusCode, !(200..<300).contains(status) {
            fail(BackgroundModelDownloaderError.unavailable)
            return
        }

        reportProgress()
        resumeIfComplete()
    }

    private func resumeIfComplete() {
        let continuation = lock.withLock { () -> CheckedContinuation<Void, Error>? in
            guard let plan else { return nil }
            let directory = Self.url(forStoredPath: plan.directory)
            guard plan.files.allSatisfy({ Self.isComplete(directory.appending(path: $0.key), size: $0.value) }) else { return nil }
            defer { self.continuation = nil }
            return self.continuation
        }
        continuation?.resume()
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        let completion = lock.withLock {
            defer { backgroundCompletion = nil }
            return backgroundCompletion
        }
        DispatchQueue.main.async { completion?() }
    }

    private func fail(_ error: Error) {
        let continuation = lock.withLock {
            defer { self.continuation = nil }
            return self.continuation
        }
        session.getAllTasks { $0.forEach { $0.cancel() } }
        continuation?.resume(throwing: error)
    }

    private func reportProgress() {
        let (fraction, handler) = lock.withLock { () -> (Double, (@MainActor (Double) -> Void)?) in
            guard let plan, plan.totalBytes > 0 else { return (0, progressHandler) }
            let directory = Self.url(forStoredPath: plan.directory)
            let received = plan.files.reduce(Int64(0)) { sum, file in
                let done = Self.isComplete(directory.appending(path: file.key), size: file.value)
                return sum + (done ? file.value : min(bytesWritten[file.key] ?? 0, file.value))
            }
            return (Double(received) / Double(plan.totalBytes), progressHandler)
        }
        guard let handler else { return }
        Task { @MainActor in handler(fraction) }
    }

    // MARK: - Arquivos

    private static var savedPlan: Plan? {
        UserDefaults.standard.data(forKey: planKey).flatMap { try? JSONDecoder().decode(Plan.self, from: $0) }
    }

    private static func isComplete(_ url: URL, size: Int64) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? Int64 else { return false }
        return size == 0 || fileSize == size
    }

    private static func storedPath(for url: URL) -> String {
        let base = URL.applicationSupportDirectory.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        return String(path.dropFirst(path.hasPrefix(base) ? base.count : 0))
    }

    private static func url(forStoredPath path: String) -> URL {
        URL.applicationSupportDirectory.appending(path: path, directoryHint: .isDirectory)
    }
}

nonisolated enum BackgroundModelDownloaderError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable: "Não foi possível falar com o servidor do AgroBot. Confira sua internet e tente de novo."
        }
    }
}
