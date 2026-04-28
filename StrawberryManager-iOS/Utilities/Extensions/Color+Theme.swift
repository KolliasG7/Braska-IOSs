// Color+Theme.swift
// Bridge legacy Color extension names to AppColors

import SwiftUI

extension Color {
    // Legacy bridge names used by existing code
    static var appBackground: Color { AppColors.bgBottom }
    static var cpuColor: Color { AppColors.cyan }
    static var ramColor: Color { AppColors.violet }
    static var tempColor: Color { AppColors.orange }
}
