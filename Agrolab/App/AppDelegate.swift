//
//  AppDelegate.swift
//  Agrolab
//

import UIKit

/// Retoma o download do modelo do AgroBot feito em segundo plano (URLSession background).
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        if BackgroundModelDownloader.shared.hasPendingDownload {
            BackgroundModelDownloader.shared.reconnect()
        }
        return true
    }

    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        guard identifier == BackgroundModelDownloader.sessionIdentifier else {
            completionHandler()
            return
        }
        BackgroundModelDownloader.shared.handleBackgroundEvents(completion: completionHandler)
    }
}
