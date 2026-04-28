// ControlTab.swift
// Fan, LED, and power controls with glass design

import SwiftUI

struct ControlTab: View {
    @ObservedObject var viewModel: ControlViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                if let error = viewModel.errorMessage {
                    errorBanner(error)
                }

                FanControlCard(viewModel: viewModel)
                LEDControlCard(viewModel: viewModel)
                PowerControlsCard(viewModel: viewModel)

                Spacer().frame(height: AppSpacing.xxl)
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.top, AppSpacing.sm)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        GlassCardView(padding: AppSpacing.md, style: .subtle, tint: AppColors.danger.opacity(0.1)) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppColors.danger)
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.danger)
                Spacer()
                Button { viewModel.errorMessage = nil } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textDim)
                }
            }
        }
    }
}

// MARK: - Fan Control

struct FanControlCard: View {
    @ObservedObject var viewModel: ControlViewModel
    @State private var tempThreshold: Double

    init(viewModel: ControlViewModel) {
        self.viewModel = viewModel
        _tempThreshold = State(initialValue: Double(viewModel.currentFanThreshold))
    }

    var body: some View {
        let tColor = Color.fanThresholdColor(for: Int(tempThreshold))

        GlassCardView(tint: tColor.opacity(0.06)) {
            VStack(spacing: AppSpacing.xl) {
                StatLabel("FAN CONTROL")

                // Large temperature display
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(tempThreshold))")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(tColor)
                    Text("C")
                        .font(.title)
                        .foregroundStyle(AppColors.textDim)
                }

                // Slider
                VStack(spacing: AppSpacing.sm) {
                    Slider(value: $tempThreshold, in: -10...80, step: 1)
                        .tint(tColor)
                        .disabled(viewModel.isUpdatingFan)

                    HStack {
                        Text("-10C").font(.caption).foregroundStyle(AppColors.textDim)
                        Spacer()
                        Text("80C").font(.caption).foregroundStyle(AppColors.textDim)
                    }
                }

                // Apply button
                GlassActionButton(
                    title: viewModel.isUpdatingFan ? "Applying..." : "Apply Threshold",
                    icon: "checkmark.circle",
                    color: tColor,
                    isLoading: viewModel.isUpdatingFan
                ) {
                    viewModel.setFanThreshold(Int(tempThreshold))
                }

                Text("Lower threshold = Fan starts cooling earlier")
                    .font(.caption)
                    .foregroundStyle(AppColors.textDim)
                    .multilineTextAlignment(.center)
            }
        }
        .onChange(of: viewModel.currentFanThreshold) { _, newValue in
            tempThreshold = Double(newValue)
        }
    }
}

// MARK: - LED Control

struct LEDControlCard: View {
    @ObservedObject var viewModel: ControlViewModel

    var body: some View {
        GlassCardView(tint: AppColors.glassTintAmber) {
            VStack(spacing: AppSpacing.lg) {
                HStack {
                    StatLabel("LED CONTROL")
                    Spacer()
                    Text(viewModel.selectedLEDProfile.capitalized)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.textPri)
                }

                if !viewModel.availableLEDProfiles.isEmpty {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: AppSpacing.md) {
                        ForEach(viewModel.availableLEDProfiles, id: \.self) { profile in
                            ledButton(profile)
                        }
                    }
                }
            }
        }
    }

    private func ledButton(_ profile: String) -> some View {
        let selected = viewModel.selectedLEDProfile == profile

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            viewModel.setLEDProfile(profile)
        } label: {
            VStack(spacing: 6) {
                Circle()
                    .fill(ledColor(for: profile))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle().strokeBorder(.white.opacity(selected ? 0.4 : 0), lineWidth: 2)
                    )

                Text(profile.capitalized)
                    .font(.system(size: 11, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? AppColors.textPri : AppColors.textDim)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .background(
                selected ? AppColors.glassRaised : .clear,
                in: RoundedRectangle(cornerRadius: AppRadii.sm)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadii.sm)
                    .strokeBorder(selected ? AppColors.glassBorderHi : .clear, lineWidth: 1)
            )
        }
        .disabled(viewModel.isUpdatingLED)
    }

    private func ledColor(for profile: String) -> Color {
        switch profile.lowercased() {
        case "white":  return .white
        case "blue":   return .blue
        case "red":    return .red
        case "green":  return .green
        case "pink":   return .pink
        case "orange": return .orange
        case "purple": return .purple
        case "cyan":   return .cyan
        case "off":    return AppColors.textDim
        default:       return AppColors.accent
        }
    }
}

// MARK: - Power Controls

struct PowerControlsCard: View {
    @ObservedObject var viewModel: ControlViewModel
    @State private var showConfirmation: PowerAction? = nil

    enum PowerAction: String, Identifiable {
        case shutdown, reboot, safemode
        var id: String { rawValue }

        var title: String {
            switch self {
            case .shutdown: return "Shut Down"
            case .reboot:   return "Reboot"
            case .safemode: return "Safe Mode"
            }
        }

        var icon: String {
            switch self {
            case .shutdown: return "power"
            case .reboot:   return "arrow.clockwise"
            case .safemode: return "shield"
            }
        }

        var apiAction: String {
            switch self {
            case .shutdown: return "shutdown"
            case .reboot:   return "reboot"
            case .safemode: return "safe-mode"
            }
        }
    }

    var body: some View {
        GlassCardView(tint: AppColors.glassTintRed) {
            VStack(spacing: AppSpacing.lg) {
                StatLabel("POWER")

                HStack(spacing: AppSpacing.md) {
                    powerButton(.shutdown, color: AppColors.danger)
                    powerButton(.reboot, color: AppColors.amber)
                    powerButton(.safemode, color: AppColors.violet)
                }
            }
        }
        .alert(item: $showConfirmation) { action in
            Alert(
                title: Text(action.title),
                message: Text("Are you sure you want to \(action.title.lowercased())?"),
                primaryButton: .destructive(Text(action.title)) {
                    viewModel.powerAction(action.apiAction)
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func powerButton(_ action: PowerAction, color: Color) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showConfirmation = action
        } label: {
            VStack(spacing: 6) {
                Image(systemName: action.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
                Text(action.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.textSec)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: AppRadii.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadii.md)
                    .strokeBorder(color.opacity(0.2), lineWidth: 1)
            )
        }
    }
}
