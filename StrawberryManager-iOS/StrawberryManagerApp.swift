// StrawberryManagerApp.swift
// Main app entry point

import SwiftUI

@main
struct StrawberryManagerApp: App {
    @StateObject private var connectionViewModel = ConnectionViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectionViewModel)
                .preferredColorScheme(.dark)
        }
    }
}
