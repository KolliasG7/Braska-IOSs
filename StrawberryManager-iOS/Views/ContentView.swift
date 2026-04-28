// ContentView.swift
// Root view with animated transition between Connect and Dashboard

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var connectionViewModel: ConnectionViewModel

    var body: some View {
        Group {
            switch connectionViewModel.state {
            case .connected:
                if let api = connectionViewModel.apiService,
                   let url = URL(string: connectionViewModel.effectiveBaseURL) {
                    DashboardView(
                        apiService: api,
                        baseURL: url,
                        token: connectionViewModel.token
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96)),
                        removal: .opacity.combined(with: .scale(scale: 1.02))
                    ))
                } else {
                    ConnectView()
                }
            default:
                ConnectView()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96)),
                        removal: .opacity.combined(with: .scale(scale: 1.02))
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.38), value: connectionViewModel.state)
    }
}
