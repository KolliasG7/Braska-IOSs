// TelemetryGraph.swift
// Sparkline-style telemetry graph with glass styling

import SwiftUI

struct TelemetryGraph: View {
    let data: [Double]
    let color: Color
    var maxValue: Double = 100

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Fill gradient
                if data.count > 1 {
                    Path { path in
                        let points = normalizedPoints(width: w, height: h)
                        guard let first = points.first else { return }
                        path.move(to: CGPoint(x: first.x, y: h))
                        path.addLine(to: first)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                        path.addLine(to: CGPoint(x: points.last!.x, y: h))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // Line
                    Path { path in
                        let points = normalizedPoints(width: w, height: h)
                        guard let first = points.first else { return }
                        path.move(to: first)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }

    private func normalizedPoints(width: CGFloat, height: CGFloat) -> [CGPoint] {
        guard data.count > 1 else { return [] }
        let step = width / CGFloat(data.count - 1)
        return data.enumerated().map { i, value in
            let x = CGFloat(i) * step
            let y = height - (CGFloat(value / maxValue) * height)
            return CGPoint(x: x, y: max(0, min(height, y)))
        }
    }
}
