// DashboardView.swift
// Main dashboard with full tab navigation

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var connectionViewModel: ConnectionViewModel
    @StateObject private var dashboardViewModel: DashboardViewModel
    @StateObject private var controlViewModel: ControlViewModel
    @StateObject private var filesViewModel: FilesViewModel
    @StateObject private var processesViewModel: ProcessesViewModel
    
    @State private var selectedTab = 0
    @State private var showingSettings = false
    
    // Initialize all view models with proper dependencies
    init(apiService: APIService, baseURL: URL, token: String) {
        _dashboardViewModel = StateObject(wrappedValue: DashboardViewModel(
            apiService: apiService,
            baseURL: baseURL,
            token: token
        ))
        _controlViewModel = StateObject(wrappedValue: ControlViewModel(apiService: apiService))
        _filesViewModel = StateObject(wrappedValue: FilesViewModel(apiService: apiService))
        _processesViewModel = StateObject(wrappedValue: ProcessesViewModel(apiService: apiService))
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Monitor Tab
            NavigationStack {
                MonitorTab(viewModel: dashboardViewModel)
                    .navigationTitle("Monitor")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: { showingSettings = true }) {
                                Image(systemName: "gearshape")
                            }
                        }
                    }
            }
            .tabItem {
                Label("Monitor", systemImage: "chart.xyaxis.line")
            }
            .tag(0)
            
            // Control Tab
            NavigationStack {
                ControlTab(viewModel: controlViewModel)
                    .navigationTitle("Control")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Control", systemImage: "slider.horizontal.3")
            }
            .tag(1)
            
            // Terminal Tab
            NavigationStack {
                TerminalView(
                    baseURL: dashboardViewModel.apiService.baseURL,
                    token: connectionViewModel.token
                )
            }
            .tabItem {
                Label("Terminal", systemImage: "terminal")
            }
            .tag(2)
            
            // Files Tab
            NavigationStack {
                FilesView(viewModel: filesViewModel)
            }
            .tabItem {
                Label("Files", systemImage: "folder")
            }
            .tag(3)
            
            // Processes Tab
            NavigationStack {
                ProcessesView(viewModel: processesViewModel)
            }
            .tabItem {
                Label("Processes", systemImage: "list.bullet")
            }
            .tag(4)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

#Preview {
    let mockAPI = APIService(baseURL: URL(string: "http://localhost")!, token: "")
    DashboardView(
        apiService: mockAPI,
        baseURL: URL(string: "http://localhost")!,
        token: ""
    )
    .environmentObject(ConnectionViewModel())
}
