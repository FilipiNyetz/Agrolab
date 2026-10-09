//
//  PermissionsService.swift
//  Agrolab
//

import AVFoundation
import CoreLocation
import Observation
import UIKit
import UserNotifications

nonisolated enum PermissionKind: CaseIterable, Identifiable, Sendable {
    case location
    case notifications
    case camera

    var id: Self { self }

    var title: String {
        switch self {
        case .location: return "Localização"
        case .notifications: return "Notificações"
        case .camera: return "Câmera"
        }
    }

    var purpose: String {
        switch self {
        case .location: return "Clima e alertas de pragas da sua região."
        case .notifications: return "Avisos de alertas e resultados de análises."
        case .camera: return "Fotografar plantas para identificar pragas."
        }
    }

    var symbolName: String {
        switch self {
        case .location: return "location.fill"
        case .notifications: return "bell.badge.fill"
        case .camera: return "camera.fill"
        }
    }
}

nonisolated enum PermissionStatus: Sendable, Equatable {
    case notDetermined
    case granted
    case denied
    case restricted

    var label: String {
        switch self {
        case .notDetermined: return "Ainda não solicitada"
        case .granted: return "Permitida"
        case .denied: return "Negada nos Ajustes"
        case .restricted: return "Restrita neste aparelho"
        }
    }
}

/// Consulta e solicita as permissões do sistema usadas pelo app.
@MainActor
@Observable
final class PermissionsService {
    private(set) var statuses: [PermissionKind: PermissionStatus] = [:]
    @ObservationIgnored private let location = LocationPermissionRequester()

    func status(for kind: PermissionKind) -> PermissionStatus {
        statuses[kind] ?? .notDetermined
    }

    func refresh() async {
        statuses[.location] = Self.map(location.status)
        statuses[.camera] = Self.map(AVCaptureDevice.authorizationStatus(for: .video))
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        statuses[.notifications] = Self.map(settings.authorizationStatus)
    }

    func request(_ kind: PermissionKind) async {
        switch kind {
        case .location:
            _ = await location.request()
        case .camera:
            _ = await AVCaptureDevice.requestAccess(for: .video)
        case .notifications:
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
        }
        await refresh()
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: Mapeamentos

    private static func map(_ status: CLAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .authorizedAlways, .authorizedWhenInUse: return .granted
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .notDetermined
        }
    }

    private static func map(_ status: AVAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .authorized: return .granted
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .notDetermined
        }
    }

    private static func map(_ status: UNAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .authorized, .provisional, .ephemeral: return .granted
        case .denied: return .denied
        @unknown default: return .notDetermined
        }
    }
}

/// Mantém o CLLocationManager vivo e transforma o callback do delegate em `async`.
@MainActor
private final class LocationPermissionRequester: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLAuthorizationStatus, Never>?

    override init() {
        super.init()
        manager.delegate = self
    }

    var status: CLAuthorizationStatus { manager.authorizationStatus }

    func request() async -> CLAuthorizationStatus {
        guard manager.authorizationStatus == .notDetermined else { return manager.authorizationStatus }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = self.manager.authorizationStatus
            guard status != .notDetermined, let continuation = self.continuation else { return }
            self.continuation = nil
            continuation.resume(returning: status)
        }
    }
}
