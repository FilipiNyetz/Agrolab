//
//  AgrolabApp.swift
//  Agrolab
//
//  Created by Filipi Romão on 09/10/26.
//

import SwiftUI

@main
struct AgrolabApp: App {
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
