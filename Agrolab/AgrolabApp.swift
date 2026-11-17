//
//  AgrolabApp.swift
//  Agrolab
//
//  Created by Filipi Romão on 09/10/26.
//

import SwiftUI

@main
struct AgrolabApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container)
                .environment(container.session)
                .task { await container.session.restoreSession() }
        }
    }
}
