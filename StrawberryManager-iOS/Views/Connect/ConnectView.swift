// ConnectView.swift
// Connection screen with glass design - ported from Flutter connect_screen.dart

import SwiftUI

struct ConnectView: View {
    @EnvironmentObject var connectionViewModel: ConnectionViewModel
    @State private var address = ""
    @State private var isTunnel = false
    @State private var showPasswordSheet = false
    @State private var password = ""
    @State private var appeared = false

    var body: some View {
        GlassBackground {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    Spacer().frame(height: 48)

                    // Hero title
                    VStack(spacing: AppSpacing.sm) {
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadii.md))

                        Text("Strawberry")
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundStyle(AppColors.textPri)

                        Text("Manager")
                            .font(.system(size: 14, weight: .medium))
                            .tracking(3)
                            .foregroundStyle(AppColors.textDim)
                    }

                    Spacer().frame(height: AppSpacing.lg)

                    // Mode toggle
                    GlassCardView(padding: AppSpacing.sm, style: .subtle) {
                        HStack(spacing: 0) {
                            modeButton("Local", icon: "wifi", selected: !isTunnel) {
                                isTunnel = false
                            }
                            modeButton("Tunnel", icon: "globe", selected: isTunnel) {
                                isTunnel = true
                            }
                        }
                    }

                    // Address input
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text(isTunnel ? "TUNNEL URL" : "LOCAL ADDRESS")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(AppColors.textDim)

                        GlassTextField(
                            placeholder: isTunnel ? "abc123.trycloudflare.com" : "192.168.1.100:8080",
                            text: $address,
                            icon: isTunnel ? "globe" : "network"
                        )
                        .onAppear {
                            address = connectionViewModel.serverAddress
                        }
                    }

                    // Connect button
                    connectButton

                    // Error display
                    if case .error(let msg) = connectionViewModel.state {
                        GlassCardView(padding: AppSpacing.md, style: .subtle, tint: AppColors.danger.opacity(0.1)) {
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(AppColors.danger)
                                Text(msg)
                                    .font(.system(size: 13))
                                    .foregroundStyle(AppColors.danger)
                            }
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, AppSpacing.xl)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(.easeOut(duration: AppDurations.med), value: appeared)
        .onAppear {
            appeared = true
            if connectionViewModel.serverAddress.isEmpty == false {
                address = connectionViewModel.serverAddress
            }
        }
        .onChange(of: connectionViewModel.state) { _, newState in
            if case .needsAuth = newState {
                showPasswordSheet = true
            }
        }
        .sheet(isPresented: $showPasswordSheet) {
            PasswordSheet(password: $password) {
                connectionViewModel.login(password: password)
                password = ""
            } onCancel: {
                connectionViewModel.disconnect()
                password = ""
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private var connectButton: some View {
        let connecting = connectionViewModel.state == .connecting

        return GlassActionButton(
            title: connecting ? "Connecting..." : "Connect",
            icon: connecting ? nil : "arrow.right.circle.fill",
            isLoading: connecting
        ) {
            connectionViewModel.serverAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
            connectionViewModel.isTunnel = isTunnel
            connectionViewModel.connect()
        }
    }

    private func modeButton(_ label: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .background(
                selected ?
                    AnyShapeStyle(AppColors.accent.opacity(0.15)) :
                    AnyShapeStyle(.clear)
            )
            .foregroundStyle(selected ? AppColors.accent : AppColors.textDim)
            .clipShape(RoundedRectangle(cornerRadius: AppRadii.sm))
        }
    }
}

// MARK: - Password Sheet

struct PasswordSheet: View {
    @Binding var password: String
    let onSubmit: () -> Void
    let onCancel: () -> Void
    @State private var obscured = true

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.xl) {
                Text("Enter Strawberry Manager password.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.textSec)

                HStack {
                    if obscured {
                        SecureField("password", text: $password)
                    } else {
                        TextField("password", text: $password)
                    }

                    Button {
                        obscured.toggle()
                    } label: {
                        Image(systemName: obscured ? "eye" : "eye.slash")
                            .foregroundStyle(AppColors.textDim)
                    }
                }
                .font(.system(.body, design: .monospaced))
                .padding()
                .background(AppColors.glassSubtle, in: RoundedRectangle(cornerRadius: AppRadii.md))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadii.md)
                        .strokeBorder(AppColors.glassBorder)
                )

                HStack(spacing: AppSpacing.lg) {
                    Button("Cancel") { onCancel() }
                        .foregroundStyle(AppColors.textSec)

                    Button("Unlock") { onSubmit() }
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.accent)
                }

                Spacer()
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.top, AppSpacing.xl)
            .navigationTitle("Password")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}
