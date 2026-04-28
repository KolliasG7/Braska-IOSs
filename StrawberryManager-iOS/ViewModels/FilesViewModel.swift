// FilesViewModel.swift
// Full file browser view model - ported from Flutter

import Foundation
import Combine

@MainActor
class FilesViewModel: ObservableObject {
    @Published var currentPath: String = "/home"
    @Published var items: [APIService.FileItem] = []
    @Published var isLoading: Bool = true
    @Published var errorMessage: String?
    @Published var isUploading: Bool = false

    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    private var history: [String] = ["/home"]
    private var loadInFlight = false

    init(apiService: APIService) {
        self.apiService = apiService
        loadDirectory("/home")
    }

    var canGoBack: Bool { history.count > 1 }

    func loadDirectory(_ path: String) {
        guard !loadInFlight else { return }
        loadInFlight = true
        isLoading = true
        errorMessage = nil

        apiService.listFiles(path: path)
            .sink { [weak self] completion in
                self?.isLoading = false
                self?.loadInFlight = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self = self else { return }
                if let serverError = response.error, !serverError.isEmpty {
                    self.errorMessage = serverError
                    self.items = []
                } else {
                    self.currentPath = response.path ?? path
                    self.items = (response.items ?? []).sorted { a, b in
                        if a.isDirectory != b.isDirectory { return a.isDirectory }
                        return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                    }
                }
            }
            .store(in: &cancellables)
    }

    func navigate(to path: String) {
        guard !loadInFlight else { return }
        history.append(path)
        loadDirectory(path)
    }

    func goBack() {
        guard !loadInFlight, history.count > 1 else { return }
        history.removeLast()
        loadDirectory(history.last!)
    }

    func refresh() {
        loadDirectory(currentPath)
    }

    func deleteFile(at path: String) {
        apiService.deleteFile(path: path)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.refresh()
                }
            } receiveValue: { _ in }
            .store(in: &cancellables)
    }

    func downloadFile(at path: String) -> AnyPublisher<Data, APIError> {
        apiService.downloadFile(path: path)
    }

    func uploadFile(data: Data, filename: String) {
        isUploading = true
        apiService.uploadFile(data: data, filename: filename, destDir: currentPath)
            .sink { [weak self] completion in
                self?.isUploading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.refresh()
                }
            } receiveValue: { _ in }
            .store(in: &cancellables)
    }
}
