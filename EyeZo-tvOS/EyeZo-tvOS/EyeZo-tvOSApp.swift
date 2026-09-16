//
//  EyeZo-tvOSApp.swift
//  EyeZo-tvOS
//
//  Created by Anders Brownworth on 5/16/26.
//

import SwiftUI

@main
struct EyeZoApp: App {
    @ObservedObject private var serverURLManager = ServerURLManager.shared

    var body: some Scene {
        WindowGroup {
            if let serverURL = serverURLManager.serverURL {
                // Keyed on the URL so changing servers rebuilds the browser at
                // its root instead of refreshing a path from the old server.
                // Connection problems surface in the browser's error state.
                DirectoryBrowserView()
                    .id(serverURL)
            } else {
                ServerSetupView()
            }
        }
    }
}
