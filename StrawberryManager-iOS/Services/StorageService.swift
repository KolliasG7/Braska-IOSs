// StorageService.swift
// UserDefaults wrapper for persistent storage

import Foundation

class StorageService {
    static let shared = StorageService()
    private let defaults = UserDefaults.standard

    private init() {}

    var serverAddress: String? {
        get { defaults.string(forKey: "ps4_addr") }
        set { defaults.set(newValue, forKey: "ps4_addr") }
    }

    var isTunnel: Bool {
        get { defaults.bool(forKey: "ps4_is_tunnel") }
        set { defaults.set(newValue, forKey: "ps4_is_tunnel") }
    }

    var authToken: String? {
        get { defaults.string(forKey: "ps4_token") }
        set { defaults.set(newValue, forKey: "ps4_token") }
    }

    func getBool(_ key: String) -> Bool? {
        defaults.object(forKey: key) == nil ? nil : defaults.bool(forKey: key)
    }

    func setBool(_ key: String, _ value: Bool) {
        defaults.set(value, forKey: key)
    }

    func getString(_ key: String) -> String? {
        defaults.string(forKey: key)
    }

    func setString(_ key: String, _ value: String?) {
        defaults.set(value, forKey: key)
    }

    func clearAll() {
        let keys = ["ps4_addr", "ps4_is_tunnel", "ps4_token",
                     "show_cpu_graph", "show_ram_graph", "show_thermal_graph",
                     "show_notifications", "reduce_motion", "ps4_led_profiles"]
        keys.forEach { defaults.removeObject(forKey: $0) }
    }
}
