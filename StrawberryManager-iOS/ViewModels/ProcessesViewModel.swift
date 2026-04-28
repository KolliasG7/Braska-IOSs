// ProcessesViewModel.swift
// Process manager view model

import Foundation
import Combine

@MainActor
class ProcessesViewModel: ObservableObject {
    @Published var processes: [ProcessInfo] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var sortBy: SortOption = .cpu
    @Published var autoRefresh: Bool = false
    
    enum SortOption: String, CaseIterable {
        case cpu = "cpu"
        case memory = "memory"
        case name = "name"
        
        var displayName: String {
            switch self {
            case .cpu: return "CPU"
            case .memory: return "Memory"
            case .name: return "Name"
            }
        }
    }
    
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    
    init(apiService: APIService) {
        self.apiService = apiService
        loadProcesses()
    }
    
    func loadProcesses() async {
        isLoading = true
        errorMessage = nil
        
        apiService.getProcesses(limit: 50, sortBy: sortBy.rawValue)
            .sink { completion in
                Task { @MainActor in
                    self.isLoading = false
                    if case .failure(let error) = completion {
                        self.errorMessage = error.localizedDescription
                    }
                }
            } receiveValue: { [weak self] processes in
                self?.processes = processes
            }
            .store(in: &cancellables)
    }
    
    func killProcess(_ process: ProcessInfo, signal: String = "SIGTERM") async {
        apiService.killProcess(process.pid, signal: signal)
            .sink { completion in
                Task { @MainActor in
                    if case .failure(let error) = completion {
                        self.errorMessage = error.localizedDescription
                    } else {
                        // Reload after successful kill
                        await self.loadProcesses()
                    }
                }
            } receiveValue: { _ in }
            .store(in: &cancellables)
    }
    
    func toggleAutoRefresh() {
        autoRefresh.toggle()
        if autoRefresh {
            startAutoRefresh()
        } else {
            stopAutoRefresh()
        }
    }
    
    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.loadProcesses()
            }
        }
    }
    
    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    deinit {
        Task { @MainActor in
            await stopAutoRefresh()
        }
    }
}
