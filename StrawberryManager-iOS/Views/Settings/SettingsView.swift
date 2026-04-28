// SettingsView.swift
// Full settings screen with glass design

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var connectionViewModel: ConnectionViewModel
    @Environment(\.dismiss) var dismiss

    @State private var showingPasswordSheet = false
    @State private var showingDisconnectAlert = false
    @State private var showingLogsView = false

    var body: some View {
        NavigationStack {
            Form {
                // Connection section
                Section("Connection") {
                    HStack {
                        Text("Server")
                        Spacer()
                        Text(connectionViewModel.serverAddress)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Button(role: .destructive) {
                        showingDisconnectAlert = true
                    } label: {
                        Label("Disconnect", systemImage: "power")
                    }
                }

                // Display preferences
                Section("Graphs") {
                    Toggle("Show CPU Graph", isOn: $connectionViewModel.showCPUGraph)
                    Toggle("Show RAM Graph", isOn: $connectionViewModel.showRAMGraph)
                    Toggle("Show Thermal Graph", isOn: $connectionViewModel.showThermalGraph)
                }

                // Notifications
                Section {
                    Toggle("Show Notifications", isOn: $connectionViewModel.showNotifications)
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Receive status notifications for temperature alerts")
                }

                // Accessibility
                Section("Accessibility") {
                    Toggle("Reduce Motion", isOn: $connectionViewModel.reduceMotion)
                }

                // Security
                Section("Security") {
                    Button {
                        showingPasswordSheet = true
                    } label: {
                        Label("Change Password", systemImage: "key")
                    }

                    Button(role: .destructive) {
                        connectionViewModel.clearToken()
                    } label: {
                        Label("Clear Saved Token", systemImage: "trash")
                    }
                }

                // Diagnostics
                Section("Diagnostics") {
                    Button {
                        showingLogsView = true
                    } label: {
                        Label("View System Logs", systemImage: "doc.text.magnifyingglass")
                    }
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://github.com/KolliasG7/Strawberry-Manager---Reworked")!) {
                        HStack {
                            Text("GitHub Repository")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        connectionViewModel.savePreferences()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingPasswordSheet) {
                ChangePasswordView()
                    .environmentObject(connectionViewModel)
            }
            .sheet(isPresented: $showingLogsView) {
                if let api = connectionViewModel.apiService {
                    LogsView(apiService: api)
                }
            }
            .alert("Disconnect", isPresented: $showingDisconnectAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Disconnect", role: .destructive) {
                    connectionViewModel.disconnectAndForget()
                    dismiss()
                }
            } message: {
                Text("This will disconnect from the server and clear all saved data.")
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Change Password

struct ChangePasswordView: View {
    @EnvironmentObject var connectionViewModel: ConnectionViewModel
    @Environment(\.dismiss) var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Current Password", text: $currentPassword)
                    SecureField("New Password", text: $newPassword)
                    SecureField("Confirm New Password", text: $confirmPassword)
                } header: {
                    Text("Change Password")
                } footer: {
                    if let error = errorMessage {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { changePassword() }
                        .disabled(isLoading || currentPassword.isEmpty || newPassword.isEmpty || newPassword != confirmPassword)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func changePassword() {
        guard newPassword == confirmPassword else {
            errorMessage = "Passwords don't match"
            return
        }
        guard newPassword.count >= 4 else {
            errorMessage = "Password must be at least 4 characters"
            return
        }

        isLoading = true
        errorMessage = nil

        connectionViewModel.apiService?.rotatePassword(currentPassword: currentPassword, newPassword: newPassword)
            .sink { completion in
                isLoading = false
                if case .failure(let error) = completion {
                    errorMessage = error.localizedDescription
                }
            } receiveValue: { newToken in
                connectionViewModel.token = newToken
                dismiss()
            }
            .store(in: &passwordCancellables)
    }

    @State private var passwordCancellables = Set<AnyCancellable>()
}

import Combine
