//
//  DeviceCapabilities.swift
//  Agrolab
//

import Foundation
import Network
import os

/// Informações do aparelho usadas para decidir se o AgroBot local pode rodar.
nonisolated enum DeviceCapabilities {
    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    static var physicalMemoryBytes: UInt64 {
        ProcessInfo.processInfo.physicalMemory
    }

    static func availableMemoryBytes() -> Int {
        #if targetEnvironment(simulator)
        Int.max
        #else
        Int(os_proc_available_memory())
        #endif
    }

    static func freeDiskSpaceBytes() -> Int64 {
        let values = try? URL.homeDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage ?? 0
    }

    static func isOnExpensiveNetwork() async -> Bool {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let once = ResumeOnce()
            monitor.pathUpdateHandler = { path in
                guard once.claim() else { return }
                monitor.cancel()
                continuation.resume(returning: path.isExpensive)
            }
            monitor.start(queue: DispatchQueue(label: "DeviceCapabilities.network"))
        }
    }
}

nonisolated private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false

    func claim() -> Bool {
        lock.withLock {
            defer { claimed = true }
            return !claimed
        }
    }
}
