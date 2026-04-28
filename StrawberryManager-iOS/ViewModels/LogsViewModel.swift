// LogsViewModel.swift
// Journalctl log viewer view model

import Foundation
import Combine

@MainActor
class LogsViewModel: ObservableObject {
    @Published var entries: [String] = []
    @Published var isLoading: Bool = true
    @Published var errorMessage: String?
    @Published var lineCount: Int = 500
    @Published var priority: String? = nil

    static let lineOptions = [100, 500, 1000, 2000]
    static let priorityOptions: [(value: String?, label: String)] = [
        (nil, "All"),
        ("3", "Errors"),
        ("4", "Warnings+"),
        ("6", "Info+"),
        ("7", "Debug"),
    ]

    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    private var inFlight = false

    init(apiService: APIService) {
        self.apiService = apiService
        loadLogs()
    }

    func loadLogs() {
        guard !inFlight else { return }
        inFlight = true
        isLoading = true
        errorMessage = nil

        apiService.fetchLogs(lines: lineCount, priority: priority)
            .sink { [weak self] completion in
                self?.isLoading = false
                self?.inFlight = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                self?.entries = response.lines ?? []
            }
            .store(in: &cancellables)
    }

    func setLineCount(_ count: Int) {
        lineCount = count
        loadLogs()
    }

    func setPriority(_ p: String?) {
        priority = p
        loadLogs()
    }
}
