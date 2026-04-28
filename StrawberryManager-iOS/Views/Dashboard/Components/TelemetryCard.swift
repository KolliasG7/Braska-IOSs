// TelemetryCard.swift
// Reusable telemetry card wrapper with glass design

import SwiftUI

struct TelemetryCard<Content: View>: View {
    let title: String
    var icon: String = ""
    var accentColor: Color = AppColors.accent
    let content: Content

    init(
        title: String,
        icon: String = "",
        accentColor: Color = AppColors.accent,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.accentColor = accentColor
        self.content = content()
    }

    var body: some View {
        GlassCardView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                if !icon.isEmpty {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: icon)
                            .font(.system(size: 14))
                            .foregroundStyle(accentColor)
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppColors.textPri)
                    }
                }

                content
            }
        }
    }
}
