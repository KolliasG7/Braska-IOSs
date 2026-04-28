// AppColors.swift
// Design tokens: glassmorphism color palette ported from Flutter theme/tokens.dart

import SwiftUI

// MARK: - Core Color Palette (Bk equivalent)

enum AppColors {
    // Backdrop
    static let bgTop    = Color(hex: 0x0B0D1F)
    static let bgBottom = Color(hex: 0x05060F)
    static let bgOrbA   = Color(hex: 0x4F46E5) // top-left halo
    static let bgOrbB   = Color(hex: 0xF472B6) // bottom-right halo
    static let bgOrbC   = Color(hex: 0x22D3EE) // mid-right cyan halo

    // Surfaces
    static let surface0 = Color(hex: 0x0A0C1C)
    static let surface1 = Color(hex: 0x12152A)
    static let surface2 = Color(hex: 0x1A1D33)

    // Text
    static let textPri = Color(hex: 0xF5F7FA)
    static let textSec = Color(hex: 0xB4B8C5)
    static let textDim = Color(hex: 0x6A6F80)

    // Accent
    static let accent     = Color(hex: 0x7DD3FC) // sky-300
    static let accentSoft = Color(hex: 0x7DD3FC).opacity(0.2)

    // Status
    static let success = Color(hex: 0x34D399)
    static let warn    = Color(hex: 0xFBBF24)
    static let danger  = Color(hex: 0xF87171)

    // Named aliases
    static let cyan     = accent
    static let cyanDim  = Color(hex: 0x5FAFD1)
    static let cyanGlow = Color(hex: 0x7DD3FC).opacity(0.2)
    static let amber    = warn
    static let red      = danger
    static let green    = success
    static let violet   = Color(hex: 0xA5B4FC)
    static let orange   = Color(hex: 0xFB923C)
    static let pink     = Color(hex: 0xF9A8D4)

    // Glass surface colors
    static let glassSubtle   = Color.white.opacity(0.06)
    static let glassDefault  = Color.white.opacity(0.08)
    static let glassRaised   = Color.white.opacity(0.12)
    static let glassBorder   = Color.white.opacity(0.10)
    static let glassBorderHi = Color.white.opacity(0.14)

    // Glass tints
    static let glassTint       = Color.white.opacity(0.03)
    static let glassTintCyan   = Color(hex: 0x7DD3FC).opacity(0.06)
    static let glassTintAmber  = Color(hex: 0xFBBF24).opacity(0.06)
    static let glassTintViolet = Color(hex: 0xA5B4FC).opacity(0.06)
    static let glassTintRed    = Color(hex: 0xF87171).opacity(0.06)

    // Borders
    static let border     = Color.white.opacity(0.10)
    static let borderGlow = Color.white.opacity(0.20)

    // Chart gradients
    static let cpuGrad  = [Color(hex: 0x7DD3FC), Color(hex: 0xF5F7FA)]
    static let ramGrad  = [Color(hex: 0xA5B4FC), Color(hex: 0xF5F7FA)]
    static let tempGrad = [Color(hex: 0xFB923C), Color(hex: 0xF87171)]
    static let diskGrad = [Color(hex: 0x6EE7B7), Color(hex: 0xF5F7FA)]
    static let netGrad  = [Color(hex: 0x7DD3FC), Color(hex: 0xA5B4FC)]
}

// MARK: - Spacing Tokens

enum AppSpacing {
    static let xs:   CGFloat = 4
    static let sm:   CGFloat = 8
    static let md:   CGFloat = 12
    static let lg:   CGFloat = 16
    static let xl:   CGFloat = 20
    static let xxl:  CGFloat = 24
    static let xxxl: CGFloat = 32
}

// MARK: - Radii Tokens

enum AppRadii {
    static let sm:   CGFloat = 8
    static let md:   CGFloat = 12
    static let lg:   CGFloat = 16
    static let xl:   CGFloat = 20
    static let pill:  CGFloat = 28
}

// MARK: - Duration Tokens

enum AppDurations {
    static let fast: Double = 0.18
    static let med:  Double = 0.30
    static let slow: Double = 0.50
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8)  & 0xFF) / 255.0,
            blue:  Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

// MARK: - Semantic Color Helpers

extension Color {
    static func percentColor(_ p: Double) -> Color {
        p >= 90 ? AppColors.red : p >= 70 ? AppColors.amber : AppColors.cyan
    }

    static func temperatureColor(for t: Double) -> Color {
        t >= 88 ? AppColors.red
            : t >= 72 ? AppColors.amber
            : t >= 55 ? Color(hex: 0xFFD166)
            : AppColors.green
    }

    static func fanThresholdColor(for celsius: Int) -> Color {
        celsius >= 70 ? AppColors.red
            : celsius >= 55 ? AppColors.amber
            : AppColors.cyan
    }
}
