// DashboardView.swift
// Main dashboard with glass bottom navigation and tab content

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var connectionViewModel: ConnectionViewModel
    @StateObject private var dashboardViewModel: DashboardViewModel
    @StateObject private var controlViewModel: ControlViewModel
    @StateObject private var filesViewModel: FilesViewModel
    @StateObject private var processesViewModel: ProcessesViewModel

    @State private var selectedTab = 0
    @State private var showingSettings = false
    @State private var appeared = false

    init(apiService: APIService, baseURL: URL, token: String) {
        _dashboardViewModel = StateObject(wrappedValue: DashboardViewModel(
            apiService: apiService, baseURL: baseURL, token: token
        ))
        _controlViewModel = StateObject(wrappedValue: ControlViewModel(apiService: apiService))
        _filesViewModel = StateObject(wrappedValue: FilesViewModel(apiService: apiService))
        _processesViewModel = StateObject(wrappedValue: ProcessesViewModel(apiService: apiService))
    }

    private let destinations = [
        NavDestination(icon: "chart.xyaxis.line", label: "Monitor"),
        NavDestination(icon: "slider.horizontal.3", label: "Control"),
        NavDestination(icon: "terminal", label: "Shell"),
        NavDestination(icon: "folder", label: "Files"),
    ]

    var body: some View {
        GlassBackground {
            VStack(spacing: 0) {
                // Top bar
                topBar

                // Reconnect banner
                if dashboardViewModel.webSocketState == .connecting && dashboardViewModel.telemetryFrame != nil {
                    reconnectBanner
                }

                // Tab content
                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Glass bottom nav
                GlassBottomNav(
                    selectedIndex: selectedTab,
                    destinations: destinations.enumerated().map { i, d in
                        NavDestination(
                            icon: d.icon,
                            label: d.label,
                            badge: i == 0 && (dashboardViewModel.telemetryFrame?.cpu?.percent ?? 0) > 80
                        )
                    },
                    onTap: { selectedTab = $0 }
                )
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .animation(.easeOut(duration: AppDurations.med), value: appeared)
        .onAppear { appeared = true }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(connectionViewModel)
        }
        .onChange(of: dashboardViewModel.telemetryFrame) { _, frame in
            if let frame = frame {
                connectionViewModel.addTelemetryData(frame: frame)
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Strawberry")
                    .font(.system(size: 22, weight: .heavy))
                    .tracking(-0.2)
                    .foregroundStyle(AppColors.textPri)

                Text(dashboardViewModel.telemetryFrame == nil
                     ? "Connecting..."
                     : "Uptime \(dashboardViewModel.telemetryFrame!.uptimeFormatted)")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textSec)
            }

            Spacer()

            ConnectionStatusPill(state: dashboardViewModel.webSocketState)

            GlassIconButton(icon: "gearshape", action: { showingSettings = true }, size: 40)
                .padding(.leading, AppSpacing.sm)
        }
        .padding(.horizontal, AppSpacing.xl)
        .padding(.vertical, AppSpacing.md)
    }

    // MARK: - Reconnect Banner

    private var reconnectBanner: some View {
        HStack(spacing: AppSpacing.sm) {
            ProgressView()
                .tint(AppColors.warn)
            Text("Reconnecting...")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.warn)
            Spacer()
            Button("Retry") {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                dashboardViewModel.retryConnection()
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AppColors.accent)
        }
        .padding(.horizontal, AppSpacing.xl)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.warn.opacity(0.08))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0:
            MonitorTab(viewModel: dashboardViewModel)
        case 1:
            ControlTab(viewModel: controlViewModel)
        case 2:
            TerminalView(
                baseURL: dashboardViewModel.apiService.baseURL,
                token: connectionViewModel.token
            )
        case 3:
            FilesView(viewModel: filesViewModel)
        default:
            MonitorTab(viewModel: dashboardViewModel)
        }
    }
}
