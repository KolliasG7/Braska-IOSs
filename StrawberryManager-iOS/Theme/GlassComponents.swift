// GlassComponents.swift
// Glass-styled buttons, inputs, and bottom navigation

import SwiftUI

// MARK: - Glass Icon Button

struct GlassIconButton: View {
    let icon: String
    let action: () -> Void
    var size: CGFloat = 40
    var tooltip: String? = nil

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundStyle(AppColors.textPri)
                .frame(width: size, height: size)
                .background(.ultraThinMaterial, in: Circle())
                .environment(\.colorScheme, .dark)
                .overlay(Circle().strokeBorder(AppColors.glassBorder, lineWidth: 1))
        }
        .accessibilityLabel(tooltip ?? icon)
    }
}

// MARK: - Glass Text Field

struct GlassTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var icon: String? = nil

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundStyle(AppColors.textDim)
                    .frame(width: 20)
            }

            if isSecure {
                SecureField(placeholder, text: $text)
                    .foregroundStyle(AppColors.textPri)
            } else {
                TextField(placeholder, text: $text)
                    .foregroundStyle(AppColors.textPri)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.glassSubtle, in: RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous)
                .strokeBorder(AppColors.glassBorder, lineWidth: 1)
        )
        .font(.system(.body, design: .monospaced))
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
    }
}

// MARK: - Glass Bottom Navigation

struct GlassBottomNav: View {
    let selectedIndex: Int
    let destinations: [NavDestination]
    let onTap: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(destinations.indices, id: \.self) { index in
                let dest = destinations[index]
                let selected = index == selectedIndex

                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    onTap(index)
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            Image(systemName: dest.icon)
                                .font(.system(size: 20, weight: selected ? .semibold : .regular))
                                .foregroundStyle(selected ? AppColors.accent : AppColors.textDim)

                            if dest.badge {
                                Circle()
                                    .fill(AppColors.danger)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 10, y: -10)
                            }
                        }

                        Text(dest.label)
                            .font(.system(size: 10, weight: selected ? .semibold : .regular))
                            .foregroundStyle(selected ? AppColors.accent : AppColors.textDim)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.sm)
                }
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.top, AppSpacing.sm)
        .padding(.bottom, AppSpacing.xs)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppColors.glassBorder)
                .frame(height: 0.5)
        }
    }
}

struct NavDestination {
    let icon: String
    let label: String
    var badge: Bool = false
}

// MARK: - Glass Action Button

struct GlassActionButton: View {
    let title: String
    var icon: String? = nil
    var color: Color = AppColors.accent
    var isLoading: Bool = false
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            HStack(spacing: AppSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(isDestructive ? AppColors.danger : color)
                }

                if let icon = icon, !isLoading {
                    Image(systemName: icon)
                }

                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous)
                    .fill((isDestructive ? AppColors.danger : color).opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous)
                    .strokeBorder((isDestructive ? AppColors.danger : color).opacity(0.3), lineWidth: 1)
            )
            .foregroundStyle(isDestructive ? AppColors.danger : color)
        }
        .disabled(isLoading)
    }
}

// MARK: - Connection Status Pill

struct ConnectionStatusPill: View {
    let state: WebSocketState

    private var color: Color {
        switch state {
        case .connected:    return AppColors.success
        case .connecting:   return AppColors.warn
        case .disconnected: return AppColors.textDim
        }
    }

    private var label: String {
        switch state {
        case .connected:    return "LIVE"
        case .connecting:   return "CONNECTING"
        case .disconnected: return "OFFLINE"
        }
    }

    var body: some View {
        GlassPill {
            HStack(spacing: 6) {
                PulsingDot(color: color, pulse: state == .connected)

                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(color)
            }
        }
    }
}

// MARK: - Pulsing Dot

struct PulsingDot: View {
    let color: Color
    var pulse: Bool = false
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .scaleEffect(isPulsing && pulse ? 1.3 : 1.0)
            .opacity(isPulsing && pulse ? 0.6 : 1.0)
            .animation(
                pulse ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true) : .default,
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}

// MARK: - Arc Gauge

struct ArcGauge: View {
    let value: Double // 0-1
    let color: Color
    let label: String
    let sub: String
    var size: CGFloat = 88

    var body: some View {
        ZStack {
            // Background arc
            ArcShape(startAngle: .degrees(135), endAngle: .degrees(405))
                .stroke(AppColors.border, style: StrokeStyle(lineWidth: 5.5, lineCap: .round))

            // Value arc
            if value > 0 {
                ArcShape(
                    startAngle: .degrees(135),
                    endAngle: .degrees(135 + 270 * min(value, 1.0))
                )
                .stroke(
                    AngularGradient(
                        colors: [color.opacity(0.4), color],
                        center: .center,
                        startAngle: .degrees(135),
                        endAngle: .degrees(135 + 270 * min(value, 1.0))
                    ),
                    style: StrokeStyle(lineWidth: 5.5, lineCap: .round)
                )
            }

            // Center label
            VStack(spacing: 1) {
                Text(label)
                    .font(.system(size: size * 0.215, weight: .black, design: .rounded))
                    .foregroundStyle(color)

                Text(sub)
                    .font(.system(size: size * 0.115))
                    .tracking(0.5)
                    .foregroundStyle(AppColors.textDim)
            }
        }
        .frame(width: size, height: size)
    }
}

struct ArcShape: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - 7
        var path = Path()
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        return path
    }
}

// MARK: - Stat Label

struct StatLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .tracking(1.5)
            .foregroundStyle(AppColors.textDim)
    }
}

// MARK: - Metric Row

struct MetricRow: View {
    let label: String
    let value: String
    var color: Color = AppColors.textPri

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(AppColors.textSec)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
        }
    }
}
