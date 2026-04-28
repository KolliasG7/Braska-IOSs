// GlassBackground.swift
// Dark gradient backdrop with orbital halos - ported from Flutter shell.dart

import SwiftUI

struct GlassBackground<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [AppColors.bgTop, AppColors.bgBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Orbital halos
            GeometryReader { geo in
                // Top-left indigo halo
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AppColors.bgOrbA.opacity(0.15), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.5
                        )
                    )
                    .frame(width: geo.size.width * 0.8, height: geo.size.width * 0.8)
                    .position(x: geo.size.width * 0.15, y: geo.size.height * 0.1)

                // Bottom-right pink halo
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AppColors.bgOrbB.opacity(0.10), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.5
                        )
                    )
                    .frame(width: geo.size.width * 0.7, height: geo.size.width * 0.7)
                    .position(x: geo.size.width * 0.85, y: geo.size.height * 0.85)

                // Mid-right cyan halo
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AppColors.bgOrbC.opacity(0.08), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.35
                        )
                    )
                    .frame(width: geo.size.width * 0.5, height: geo.size.width * 0.5)
                    .position(x: geo.size.width * 0.8, y: geo.size.height * 0.4)
            }
            .ignoresSafeArea()

            content
        }
    }
}

// ViewModifier for applying glass background
struct GlassBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        GlassBackground { content }
    }
}

extension View {
    func glassBackground() -> some View {
        modifier(GlassBackgroundModifier())
    }
}
