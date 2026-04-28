// ConnectionViewModel.swift
// Manages connection state and authentication

import Foundation
import Combine

@MainActor
class ConnectionViewModel: ObservableObject {
    @Published var state: ConnectionState = .idle
    @Published var serverAddress: String = ""
    @Published var isTunnel: Bool = false
    @Published var token: String = ""

    private(set) var apiService: APIService?
    var api: APIService? { apiService }

    private var cancellables = Set<AnyCancellable>()
    private let storageService = StorageService.shared

    // Telemetry history for graphs
    @Published var cpuHistory: [Double] = []
    @Published var ramHistory: [Double] = []
    @Published var tempHistory: [Double] = []
    @Published var fanHistory: [Double] = []

    // Settings
    @Published var showCPUGraph: Bool = true
    @Published var showRAMGraph: Bool = true
    @Published var showThermalGraph: Bool = true
    @Published var showNotifications: Bool = true
    @Published var reduceMotion: Bool = false

    var effectiveBaseURL: String {
        detectTunnel(serverAddress) ?
            (serverAddress.hasPrefix("http") ? serverAddress : "https://\(serverAddress)") :
            "http://\(serverAddress)"
    }

    init() {
        loadSavedConnection()
    }

    func loadSavedConnection() {
        if let savedAddress = storageService.serverAddress {
            serverAddress = savedAddress
            isTunnel = storageService.isTunnel
            token = storageService.authToken ?? ""
            showCPUGraph = storageService.getBool("show_cpu_graph") ?? true
            showRAMGraph = storageService.getBool("show_ram_graph") ?? true
            showThermalGraph = storageService.getBool("show_thermal_graph") ?? true
            showNotifications = storageService.getBool("show_notifications") ?? true
            reduceMotion = storageService.getBool("reduce_motion") ?? false

            if !savedAddress.isEmpty {
                connect()
            }
        }
    }

    func connect() {
        state = .connecting
        let urlString = effectiveBaseURL

        guard let url = URL(string: urlString) else {
            state = .error("Invalid server address")
            return
        }

        let savedToken = storageService.authToken ?? ""
        apiService = APIService(baseURL: url, token: savedToken)

        apiService?.getHealth()
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.state = .error(error.localizedDescription)
                }
            } receiveValue: { [weak self] health in
                guard let self = self else { return }
                if health.authRequired == true {
                    self.verifyAuthentication()
                } else {
                    self.completeConnection()
                }
            }
            .store(in: &cancellables)
    }

    func login(password: String) {
        guard let api = apiService else { return }
        state = .connecting

        api.login(password: password)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.state = .needsAuth
                    // Keep needsAuth state but surface the error message
                    print("[ConnectionViewModel] Login failed: \(error)")
                }
            } receiveValue: { [weak self] newToken in
                self?.token = newToken
                self?.storageService.authToken = newToken
                self?.apiService?.updateToken(newToken)
                self?.completeConnection()
            }
            .store(in: &cancellables)
    }

    func disconnect() {
        state = .idle
        cancellables.removeAll()
    }

    func disconnectAndForget() {
        disconnect()
        storageService.clearAll()
        serverAddress = ""
        token = ""
        apiService = nil
    }

    func clearToken() {
        storageService.authToken = nil
        token = ""
    }

    func savePreferences() {
        storageService.setBool("show_cpu_graph", showCPUGraph)
        storageService.setBool("show_ram_graph", showRAMGraph)
        storageService.setBool("show_thermal_graph", showThermalGraph)
        storageService.setBool("show_notifications", showNotifications)
        storageService.setBool("reduce_motion", reduceMotion)
    }

    func addTelemetryData(frame: TelemetryFrame) {
        if let cpu = frame.cpu {
            cpuHistory.append(cpu.percent)
            if cpuHistory.count > 50 { cpuHistory.removeFirst() }
        }
        if let ram = frame.ram {
            ramHistory.append(ram.percent)
            if ramHistory.count > 50 { ramHistory.removeFirst() }
        }
        if let fan = frame.fan {
            tempHistory.append(fan.apuTempC)
            if tempHistory.count > 50 { tempHistory.removeFirst() }
            fanHistory.append(Double(fan.rpm))
            if fanHistory.count > 50 { fanHistory.removeFirst() }
        }
    }

    // MARK: - Private

    private func verifyAuthentication() {
        apiService?.verifyToken()
            .sink { [weak self] completion in
                if case .failure = completion {
                    self?.state = .needsAuth
                }
            } receiveValue: { [weak self] isValid in
                if isValid {
                    self?.completeConnection()
                } else {
                    self?.state = .needsAuth
                }
            }
            .store(in: &cancellables)
    }

    private func completeConnection() {
        storageService.serverAddress = serverAddress
        storageService.isTunnel = isTunnel
        state = .connected
    }

    private func detectTunnel(_ address: String) -> Bool {
        address.hasPrefix("https://") ||
        address.hasPrefix("http://") ||
        address.contains(".trycloudflare.com") ||
        address.contains(".cloudflare")
    }
}
