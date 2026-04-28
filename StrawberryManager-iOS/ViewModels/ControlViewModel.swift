// ControlViewModel.swift
// View model for fan and LED controls

import Foundation
import Combine

@MainActor
class ControlViewModel: ObservableObject {
    @Published var currentFanThreshold: Int = 70
    @Published var selectedLEDProfile: String = "white"
    @Published var availableLEDProfiles: [String] = []
    @Published var isUpdatingFan: Bool = false
    @Published var isUpdatingLED: Bool = false
    @Published var errorMessage: String?
    
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    
    init(apiService: APIService) {
        self.apiService = apiService
        loadInitialState()
    }
    
    func loadInitialState() {
        // Load fan threshold
        apiService.getFanThreshold()
            .sink { completion in
                if case .failure(let error) = completion {
                    Task { @MainActor in
                        self.errorMessage = error.localizedDescription
                    }
                }
            } receiveValue: { [weak self] threshold in
                self?.currentFanThreshold = threshold
            }
            .store(in: &cancellables)
        
        // Load LED profiles
        apiService.getLEDProfiles()
            .sink { [weak self] completion in
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
            } receiveValue: { [weak self] confirmedThreshold in
                self?.currentFanThreshold = confirmedThreshold
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
            } receiveValue: { [weak self] confirmedProfile in
                self?.selectedLEDProfile = confirmedProfile
            }
            .store(in: &cancellables)
    }
}
