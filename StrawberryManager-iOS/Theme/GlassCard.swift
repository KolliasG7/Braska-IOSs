// GlassCard.swift
// Frosted glass card component - ported from Flutter glass.dart

import SwiftUI

enum GlassStyle {
    case subtle, normal, raised

    var fill: Color {
        switch self {
        case .subtle: return AppColors.glassSubtle
        case .normal: return AppColors.glassDefault
        case .raised: return AppColors.glassRaised
        }
    }

    var border: Color {
        switch self {
        case .subtle, .normal: return AppColors.glassBorder
        case .raised:          return AppColors.glassBorderHi
        }
    }

    var sheenIntensity: Double {
        switch self {
        case .subtle: return 0.7
        case .normal: return 1.0
        case .raised: return 1.15
        }
    }
}

struct GlassCardView<Content: View>: View {
    let content: Content
    var padding: CGFloat = AppSpacing.lg
    var radius: CGFloat = AppRadii.lg
    var style: GlassStyle = .normal
    var tint: Color? = nil
    var onTap: (() -> Void)? = nil

    init(
        padding: CGFloat = AppSpacing.lg,
        radius: CGFloat = AppRadii.lg,
        style: GlassStyle = .normal,
        tint: Color? = nil,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.radius = radius
        self.style = style
        self.tint = tint
        self.onTap = onTap
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        ZStack {
            // Blur background
            shape
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)

            // Glass fill
            shape
                .fill(style.fill)

            // Tint gradient overlay
            if let tint = tint {
                shape
                    .fill(
                        LinearGradient(
                            colors: [tint, tint.opacity(0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            // Specular sheen
            LiquidGlassSheen(radius: radius, intensity: style.sheenIntensity)

            // Content
            content
                .padding(padding)
        }
        .overlay(
            shape.strokeBorder(style.border, lineWidth: 1)
        )
        .clipShape(shape)
        .contentShape(shape)
        .onTapGesture {
            onTap?()
        }
    }
}

// MARK: - Liquid Glass Sheen

struct LiquidGlassSheen: View {
    let radius: CGFloat
    var intensity: Double = 1.0

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        ZStack {
            // Top-edge specular highlight
            LinearGradient(
                colors: [
                    .white.opacity(0.22 * intensity),
                    .white.opacity(0.05 * intensity),
                    .clear,
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Diagonal hotspot from top-left
            LinearGradient(
                colors: [
                    .white.opacity(0.12 * intensity),
                    .clear,
                ],
                startPoint: .topLeading,
                endPoint: UnitPoint(x: 0.6, y: 0.5)
            )

            // Bottom dim for depth
            LinearGradient(
                colors: [
                    .black.opacity(0.08 * intensity),
                    .clear,
                ],
                startPoint: .bottom,
                endPoint: UnitPoint(x: 0.5, y: 0.65)
            )
        }
        .clipShape(shape)
        .allowsHitTesting(false)
    }
}

// MARK: - Glass Pill

struct GlassPill<Content: View>: View {
    let content: Content
    var padding: EdgeInsets = .init(top: 6, leading: 12, bottom: 6, trailing: 12)

    init(
        padding: EdgeInsets = .init(top: 6, leading: 12, bottom: 6, trailing: 12),
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial, in: Capsule())
            .environment(\.colorScheme, .dark)
            .overlay(Capsule().strokeBorder(AppColors.glassBorder, lineWidth: 1))
    }
}
