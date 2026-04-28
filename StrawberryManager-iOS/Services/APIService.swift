// APIService.swift
// HTTP API service with Combine publishers

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
}

class APIService {
    private let baseURL: URL
    private var token: String
    private let session: URLSession
    private var cancellables = Set<AnyCancellable>()
    
    init(baseURL: URL, token: String = "") {
        self.baseURL = baseURL
        self.token = token
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }
    
    func updateToken(_ newToken: String) {
        self.token = newToken
    }
    
    // MARK: - Generic Request Method
    
    private func request<T: Decodable>(
        _ endpoint: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        retries: Int = 3
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
                    let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw APIError.httpError(statusCode: httpResponse.statusCode, message: message)
                }
                
                return data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error -> APIError in
                if let apiError = error as? APIError {
                    return apiError
                } else if error is DecodingError {
                    return .decodingError(error)
                } else {
                    return .networkError(error)
                }
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Authentication
    
    struct LoginRequest: Encodable {
        let password: String
    }
    
    struct LoginResponse: Decodable {
        let token: String
    }
    
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
    
    struct FanThresholdResponse: Decodable {
        let threshold: Int
    }
    
    struct SetFanThresholdRequest: Encodable {
        let threshold: Int
    }
    
    func getFanThreshold() -> AnyPublisher<Int, APIError> {
        request("/api/fan/threshold")
            .map { (response: FanThresholdResponse) in response.threshold }
            .eraseToAnyPublisher()
    }
    
    func setFanThreshold(_ celsius: Int) -> AnyPublisher<Int, APIError> {
        guard celsius >= -10 && celsius <= 80 else {
            return Fail(error: APIError.httpError(
                statusCode: 400,
                message: "Fan threshold must be between -10°C and 80°C"
            )).eraseToAnyPublisher()
        }
        
        return request("/api/fan/threshold", method: .post, body: SetFanThresholdRequest(threshold: celsius))
            .map { (response: FanThresholdResponse) in response.threshold }
            .eraseToAnyPublisher()
    }
    
    // MARK: - LED Control
    
    struct LEDProfilesResponse: Decodable {
        let profiles: [String]
    }
    
    struct SetLEDRequest: Encodable {
        let profile: String
    }
    
    struct LEDResponse: Decodable {
        let profile: String
    }
    
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
    
    // MARK: - Process Management
    
    func getProcesses(limit: Int = 50, sortBy: String = "cpu") -> AnyPublisher<[ProcessInfo], APIError> {
        request("/api/system/processes?limit=\(limit)&sort_by=\(sortBy)")
            .map { (response: ProcessListResponse) in response.processes }
            .eraseToAnyPublisher()
    }
    
    struct KillProcessRequest: Encodable {
        let pid: Int
        let signal: String
    }
    
    func killProcess(_ pid: Int, signal: String = "SIGTERM") -> AnyPublisher<Void, APIError> {
        request("/api/system/process/kill", method: .post, body: KillProcessRequest(pid: pid, signal: signal))
            .map { (_: [String: String]) in () }
            .eraseToAnyPublisher()
    }
    
    // Additional endpoints to be implemented:
    // - File operations
    // - Power controls
    // - Tunnel management
}
