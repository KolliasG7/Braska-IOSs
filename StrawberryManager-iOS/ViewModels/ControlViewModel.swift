// ControlViewModel.swift
// Fan, LED, and power control view model

import Foundation
import Combine

@MainActor
class ControlViewModel: ObservableObject {
    @Published var currentFanThreshold: Int = 30
    @Published var isUpdatingFan: Bool = false
    @Published var availableLEDProfiles: [String] = []
    @Published var selectedLEDProfile: String = ""
    @Published var isUpdatingLED: Bool = false
    @Published var errorMessage: String?

    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()

    init(apiService: APIService) {
        self.apiService = apiService
        loadInitialData()
    }

    private func loadInitialData() {
        // Load fan threshold
        apiService.getFanThreshold()
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] threshold in
                self?.currentFanThreshold = threshold
            }
            .store(in: &cancellables)

        // Load LED profiles
        apiService.getLEDProfiles()
            .sink { completion in
                if case .failure(let error) = completion {
                    print("[ControlViewModel] Failed to load LED profiles: \(error)")
                }
            } receiveValue: { [weak self] profiles in
                self?.availableLEDProfiles = profiles
                if let first = profiles.first {
                    self?.selectedLEDProfile = first
                }
            }
            .store(in: &cancellables)

        // Load active LED
        apiService.getActiveLED()
            .sink { _ in } receiveValue: { [weak self] active in
                if let active = active {
                    self?.selectedLEDProfile = active
                }
            }
            .store(in: &cancellables)
    }

    func setFanThreshold(_ celsius: Int) {
        isUpdatingFan = true
        errorMessage = nil

        apiService.setFanThreshold(celsius)
            .sink { [weak self] completion in
                self?.isUpdatingFan = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] confirmed in
                self?.currentFanThreshold = confirmed
            }
            .store(in: &cancellables)
    }

    func setLEDProfile(_ profile: String) {
        isUpdatingLED = true
        errorMessage = nil

        apiService.setLED(profile: profile)
            .sink { [weak self] completion in
                self?.isUpdatingLED = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] confirmed in
                self?.selectedLEDProfile = confirmed
            }
            .store(in: &cancellables)
    }

    func powerAction(_ action: String) {
        apiService.powerAction(action)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { _ in }
            .store(in: &cancellables)
    }
}
