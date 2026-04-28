// APIService.swift
// HTTP API service with Combine publishers - Complete port from Flutter

import Foundation
import Combine

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case decodingError(Error)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code, let message):
            return "HTTP \(code): \(message)"
        case .decodingError(let error):
            return "Data parsing error: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }

    var isUnauth: Bool {
        if case .httpError(let code, _) = self { return code == 401 }
        return false
    }
}

class APIService {
    let baseURL: URL
    private var token: String
    private let session: URLSession
    
    init(baseURL: URL, token: String = "") {
        self.baseURL = baseURL
        self.token = token
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: configuration)
    }
    
    func updateToken(_ newToken: String) {
        self.token = newToken
    }
    
    var isTunnel: Bool {
        let s = baseURL.absoluteString
        return s.hasPrefix("https://") || s.contains(".trycloudflare.com")
    }
    
    // MARK: - Generic Request Methods
    
    private func request<T: Decodable>(
        _ endpoint: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        retries: Int = 2
    ) -> AnyPublisher<T, APIError> {
        guard let url = URL(string: endpoint, relativeTo: baseURL) else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try? JSONEncoder().encode(body)
        }
        
        return session.dataTaskPublisher(for: request)
            .retry(retries)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }
                guard (200...299).contains(httpResponse.statusCode) else {
                    var message = String(data: data, encoding: .utf8) ?? "Unknown error"
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let detail = json["detail"] as? String {
                        message = detail
                    }
                    throw APIError.httpError(statusCode: httpResponse.statusCode, message: message)
                }
                return data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error -> APIError in
                if let apiError = error as? APIError { return apiError }
                if error is DecodingError { return .decodingError(error) }
                return .networkError(error)
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    /// Raw data request (for file downloads)
    private func rawRequest(
        _ endpoint: String,
        method: HTTPMethod = .get,
        retries: Int = 2
    ) -> AnyPublisher<Data, APIError> {
        guard let url = URL(string: endpoint, relativeTo: baseURL) else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return session.dataTaskPublisher(for: request)
            .retry(retries)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }
                guard (200...299).contains(httpResponse.statusCode) else {
                    let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw APIError.httpError(statusCode: httpResponse.statusCode, message: message)
                }
                return data
            }
            .mapError { error -> APIError in
                if let apiError = error as? APIError { return apiError }
                return .networkError(error)
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    // MARK: - Authentication
    
    struct LoginRequest: Encodable { let password: String }
    struct LoginResponse: Decodable { let token: String }
    
    func login(password: String) -> AnyPublisher<String, APIError> {
        request("/auth/login", method: .post, body: LoginRequest(password: password))
            .map { (response: LoginResponse) in response.token }
            .eraseToAnyPublisher()
    }
    
    func verifyToken() -> AnyPublisher<Bool, APIError> {
        request("/auth/verify")
            .map { (_: [String: String]) in true }
            .catch { _ in Just(false).setFailureType(to: APIError.self) }
            .eraseToAnyPublisher()
    }

    struct ChangePasswordRequest: Encodable {
        let current_password: String
        let new_password: String
    }

    func rotatePassword(currentPassword: String, newPassword: String) -> AnyPublisher<String, APIError> {
        let body = ChangePasswordRequest(current_password: currentPassword, new_password: newPassword)
        return request("/auth/change-password", method: .post, body: body, retries: 0)
            .map { (response: LoginResponse) in response.token }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Health
    
    struct HealthResponse: Decodable {
        let status: String
        let authRequired: Bool?
        enum CodingKeys: String, CodingKey {
            case status
            case authRequired = "auth_required"
        }
    }
    
    func getHealth() -> AnyPublisher<HealthResponse, APIError> {
        request("/")
    }
    
    // MARK: - Fan Control
    
    struct FanThresholdResponse: Decodable { let threshold: Int }
    struct SetFanThresholdRequest: Encodable { let threshold: Int }
    struct FanConfirmedResponse: Decodable { let threshold_confirmed: Int? }
    
    func getFanThreshold() -> AnyPublisher<Int, APIError> {
        request("/api/fan/threshold")
            .map { (response: FanThresholdResponse) in response.threshold }
            .eraseToAnyPublisher()
    }
    
    func setFanThreshold(_ celsius: Int) -> AnyPublisher<Int, APIError> {
        guard celsius >= -10 && celsius <= 80 else {
            return Fail(error: APIError.httpError(
                statusCode: 400,
                message: "Fan threshold must be between -10C and 80C"
            )).eraseToAnyPublisher()
        }
        return request("/api/fan/threshold", method: .post, body: SetFanThresholdRequest(threshold: celsius))
            .map { (response: FanConfirmedResponse) in response.threshold_confirmed ?? celsius }
            .eraseToAnyPublisher()
    }
    
    // MARK: - LED Control
    
    struct LEDProfilesResponse: Decodable { let profiles: [String] }
    struct SetLEDRequest: Encodable { let profile: String }
    struct LEDResponse: Decodable { let profile: String }
    struct ActiveLEDResponse: Decodable { let active: String? }
    
    func getLEDProfiles() -> AnyPublisher<[String], APIError> {
        request("/api/led/profiles")
            .map { (response: LEDProfilesResponse) in response.profiles }
            .eraseToAnyPublisher()
    }
    
    func setLED(profile: String) -> AnyPublisher<String, APIError> {
        request("/api/led", method: .post, body: SetLEDRequest(profile: profile))
            .map { (response: LEDResponse) in response.profile }
            .eraseToAnyPublisher()
    }

    func getActiveLED() -> AnyPublisher<String?, APIError> {
        request("/api/led/active")
            .map { (response: ActiveLEDResponse) in response.active }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Process Management
    
    func getProcesses(limit: Int = 50, sortBy: String = "cpu") -> AnyPublisher<[ProcessInfo], APIError> {
        request("/api/system/processes?limit=\(limit)&sort_by=\(sortBy)")
            .map { (response: ProcessListResponse) in response.processes }
            .eraseToAnyPublisher()
    }
    
    struct KillProcessRequest: Encodable { let pid: Int; let signal: String }
    
    func killProcess(_ pid: Int, signal: String = "SIGTERM") -> AnyPublisher<Void, APIError> {
        request("/api/system/process/kill", method: .post, body: KillProcessRequest(pid: pid, signal: signal))
            .map { (_: [String: String]) in () }
            .eraseToAnyPublisher()
    }

    // MARK: - System Logs

    struct LogsResponse: Decodable {
        let unit: String?
        let lines: [String]?
        let count: Int?
        let priority: String?
    }

    func fetchLogs(lines: Int = 500, priority: String? = nil) -> AnyPublisher<LogsResponse, APIError> {
        var endpoint = "/api/system/logs?lines=\(lines)"
        if let priority = priority, !priority.isEmpty {
            endpoint += "&priority=\(priority)"
        }
        return request(endpoint)
    }

    // MARK: - Power Control

    func powerAction(_ action: String) -> AnyPublisher<Void, APIError> {
        request("/api/power/\(action)", method: .post)
            .map { (_: [String: String]) in () }
            .eraseToAnyPublisher()
    }

    // MARK: - Tunnel Management

    struct TunnelResponse: Decodable {
        let state: String?
        let url: String?
        let status: String?
    }

    func startTunnel() -> AnyPublisher<TunnelResponse, APIError> {
        request("/api/tunnel/start", method: .post)
    }

    func stopTunnel() -> AnyPublisher<Void, APIError> {
        request("/api/tunnel/stop", method: .post)
            .map { (_: [String: String]) in () }
            .eraseToAnyPublisher()
    }

    func getTunnelStatus() -> AnyPublisher<TunnelResponse, APIError> {
        request("/api/tunnel/status")
    }

    // MARK: - File Operations

    struct FileListResponse: Decodable {
        let path: String?
        let items: [FileItem]?
        let error: String?
    }

    struct FileItem: Decodable, Identifiable {
        let name: String
        let type: String // "file" or "dir"
        let size: Int?
        let modified: String?

        var id: String { name }
        var isDirectory: Bool { type == "dir" }
    }

    func listFiles(path: String) -> AnyPublisher<FileListResponse, APIError> {
        let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? path
        return request("/api/files/list?path=\(encoded)")
    }

    func downloadFile(path: String) -> AnyPublisher<Data, APIError> {
        let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? path
        return rawRequest("/api/files/download?path=\(encoded)")
    }

    func uploadFile(data: Data, filename: String, destDir: String) -> AnyPublisher<[String: String], APIError> {
        let sep = destDir.hasSuffix("/") ? "" : "/"
        let fullPath = "\(destDir)\(sep)\(filename)"
        let encoded = fullPath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fullPath

        guard let url = URL(string: "/api/files/upload?path=\(encoded)", relativeTo: baseURL) else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = data

        return session.dataTaskPublisher(for: request)
            .retry(2)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    let message = String(data: data, encoding: .utf8) ?? "Upload failed"
                    throw APIError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500, message: message)
                }
                return data
            }
            .decode(type: [String: String].self, decoder: JSONDecoder())
            .mapError { error -> APIError in
                if let apiError = error as? APIError { return apiError }
                return .networkError(error)
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func deleteFile(path: String) -> AnyPublisher<Void, APIError> {
        let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? path
        return rawRequest("/api/files/delete?path=\(encoded)", method: .delete)
            .map { _ in () }
            .eraseToAnyPublisher()
    }
}
