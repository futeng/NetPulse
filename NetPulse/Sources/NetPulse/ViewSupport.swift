import SwiftUI

struct EmptyStateView: View {
    let title: String
    let symbol: String
    let detail: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct BrandLogoMark: View {
    var body: some View {
        ZStack {
            SailfishBrandShape()
                .fill(Color(red: 0.02, green: 0.36, blue: 0.48))

            Circle()
                .fill(Color(nsColor: .windowBackgroundColor))
                .frame(width: 3.5, height: 3.5)
                .offset(x: 18, y: -1)
        }
        .frame(width: 72, height: 48)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("NetPulse 旗鱼 Logo")
    }
}

private struct SailfishBrandShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let sx = rect.width / 72
        let sy = rect.height / 48

        func point(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(
                x: rect.midX + CGFloat(x) * sx,
                y: rect.midY - CGFloat(y) * sy
            )
        }

        path.move(to: point(35, 0))
        path.addLine(to: point(16, 2.2))
        path.addCurve(
            to: point(-17, 5.5),
            control1: point(7, 7),
            control2: point(-7, 7.5)
        )
        path.addCurve(
            to: point(-19, -5.5),
            control1: point(-21, 2.5),
            control2: point(-21, -2.5)
        )
        path.addCurve(
            to: point(16, -2.2),
            control1: point(-7, -7.5),
            control2: point(7, -7)
        )
        path.closeSubpath()

        path.move(to: point(-10, 5))
        path.addCurve(
            to: point(-5, 23),
            control1: point(-9, 14),
            control2: point(-7, 20)
        )
        path.addCurve(
            to: point(9, 4.3),
            control1: point(1, 18),
            control2: point(7, 10)
        )
        path.closeSubpath()

        path.move(to: point(-17, 1.4))
        path.addLine(to: point(-34, 12))
        path.addLine(to: point(-26, 0))
        path.closeSubpath()

        path.move(to: point(-17, -1.4))
        path.addLine(to: point(-34, -12))
        path.addLine(to: point(-26, 0))
        path.closeSubpath()

        path.move(to: point(-1, -4.8))
        path.addLine(to: point(7, -14))
        path.addLine(to: point(6, -3.5))
        path.closeSubpath()

        path.move(to: point(-8, -5))
        path.addLine(to: point(-2, -12))
        path.addLine(to: point(0, -4.5))
        path.closeSubpath()

        return path
    }
}

struct StatusDot: View {
    let status: HealthStatus

    var body: some View {
        Circle()
            .fill(statusColor(status))
            .frame(width: 10, height: 10)
            .accessibilityLabel(status.title)
    }
}

func statusColor(_ status: HealthStatus) -> Color {
    switch status {
    case .idle: .secondary
    case .healthy: .green
    case .degraded: .orange
    case .down: .red
    }
}

func statusSymbol(_ status: HealthStatus) -> String {
    switch status {
    case .idle: "network"
    case .healthy: "checkmark"
    case .degraded: "exclamationmark"
    case .down: "xmark"
    }
}

func performanceColor(_ rating: PerformanceRating) -> Color {
    switch rating {
    case .idle: .secondary
    case .excellent: .green
    case .good: .teal
    case .slow, .unstable: .orange
    case .verySlow, .unavailable: .red
    }
}

func performanceSymbol(_ rating: PerformanceRating) -> String {
    switch rating {
    case .idle: "minus.circle"
    case .excellent: "checkmark.circle.fill"
    case .good: "checkmark.circle"
    case .slow: "clock.badge.exclamationmark"
    case .verySlow: "exclamationmark.triangle.fill"
    case .unstable: "waveform.path.ecg"
    case .unavailable: "xmark.circle.fill"
    }
}

func latencyColor(_ value: Double?) -> Color {
    performanceColor(latencyPerformanceRating(for: value))
}

func formatMilliseconds(_ value: Double?) -> String {
    guard let value else { return "—" }
    if value >= 1_000 {
        return String(format: "%.2fs", value / 1_000)
    }
    return "\(Int(value.rounded()))ms"
}
