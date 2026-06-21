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

struct StatusMark: View {
    let status: HealthStatus
    let isRunning: Bool
    let runner: MenuBarRunner

    var body: some View {
        ZStack {
            Circle()
                .fill(statusColor(status).opacity(0.14))
            AquariumMark(runner: runner)
                .fill(statusColor(status))
                .frame(width: 34, height: 24)
                .rotationEffect(.degrees(isRunning ? -8 : -3))
        }
        .frame(width: 48, height: 48)
        .accessibilityLabel(isRunning ? "正在检测" : status.title)
    }
}

private struct AquariumMark: Shape {
    let runner: MenuBarRunner

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let sx = rect.width / 32
        let sy = rect.height / 20
        func p(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.midX + CGFloat(x) * sx, y: rect.midY - CGFloat(y) * sy)
        }

        switch runner {
        case .arowana:
            path.move(to: p(13, 0.4))
            path.addCurve(to: p(-11, 2.7), control1: p(8, 3.2), control2: p(-4, 3.8))
            path.addCurve(to: p(-12, -1.2), control1: p(-12.4, 1.2), control2: p(-12.8, -0.1))
            path.addCurve(to: p(11, -2.0), control1: p(-5, -3.4), control2: p(6, -2.8))
            path.addLine(to: p(13, -0.8))
            path.closeSubpath()
        case .bettaFish:
            path.move(to: p(9, 0))
            path.addCurve(to: p(-5, 4.4), control1: p(5, 5.4), control2: p(-2, 5.2))
            path.addCurve(to: p(-5, -4.4), control1: p(-7.4, 2.2), control2: p(-7.4, -2.2))
            path.addCurve(to: p(9, 0), control1: p(-2, -5.2), control2: p(5, -5.4))
            path.closeSubpath()
        case .goldfish:
            path.addEllipse(in: CGRect(x: rect.midX - 7 * sx, y: rect.midY - 6 * sy, width: 16 * sx, height: 12 * sy))
            path.move(to: p(8, 0))
            path.addLine(to: p(11, 1.2))
            path.addLine(to: p(11, -1.2))
            path.closeSubpath()
        case .guppy:
            path.move(to: p(9.5, 0))
            path.addCurve(to: p(-5, 3.5), control1: p(5.5, 4.0), control2: p(-1.5, 4.2))
            path.addCurve(to: p(-5, -3.5), control1: p(-7, 1.8), control2: p(-7, -1.8))
            path.addCurve(to: p(9.5, 0), control1: p(-1.5, -4.2), control2: p(5.5, -4.0))
            path.closeSubpath()
        case .neonTetra:
            path.move(to: p(11, 0))
            path.addCurve(to: p(-8.5, 2.7), control1: p(5.5, 3.4), control2: p(-2.5, 3.4))
            path.addCurve(to: p(-8.5, -2.7), control1: p(-10.5, 1.2), control2: p(-10.5, -1.2))
            path.addCurve(to: p(11, 0), control1: p(-2.5, -3.4), control2: p(5.5, -3.4))
            path.closeSubpath()
        case .angelfish:
            path.move(to: p(9, 0))
            path.addLine(to: p(0, 8))
            path.addLine(to: p(-8, 0))
            path.addLine(to: p(0, -8))
            path.closeSubpath()
        case .pufferFish:
            path.addEllipse(in: CGRect(x: rect.midX - 8 * sx, y: rect.midY - 7 * sy, width: 16 * sx, height: 14 * sy))
            path.move(to: p(8, 0))
            path.addLine(to: p(11, 1.4))
            path.addLine(to: p(11, -1.4))
            path.closeSubpath()
        case .signalShuttle:
            path.move(to: p(12, 0))
            path.addLine(to: p(-8, 5))
            path.addLine(to: p(-4, 0.8))
            path.addLine(to: p(-8, -5))
            path.closeSubpath()
        default:
            path.move(to: p(11, 0))
            path.addCurve(to: p(-7, 5), control1: p(6, 6), control2: p(-2, 6))
            path.addCurve(to: p(-7, -5), control1: p(-10, 2.5), control2: p(-10, -2.5))
            path.addCurve(to: p(11, 0), control1: p(-2, -6), control2: p(6, -6))
            path.closeSubpath()
        }

        if runner != .signalShuttle {
            switch runner {
            case .bettaFish, .guppy:
                path.move(to: p(-5, 0))
                path.addCurve(to: p(-15, 5), control1: p(-8, 3), control2: p(-13, 5.2))
                path.addCurve(to: p(-15, -5), control1: p(-16, 1.8), control2: p(-16, -1.8))
                path.addCurve(to: p(-5, 0), control1: p(-13, -5.2), control2: p(-8, -3))
                path.closeSubpath()
            case .goldfish:
                path.addEllipse(in: CGRect(x: rect.midX - 14.5 * sx, y: rect.midY - 5.6 * sy, width: 8 * sx, height: 5.4 * sy))
                path.addEllipse(in: CGRect(x: rect.midX - 14.5 * sx, y: rect.midY + 0.2 * sy, width: 8 * sx, height: 5.4 * sy))
            default:
                path.move(to: p(-7, 0.5))
                path.addLine(to: p(-14, 5))
                path.addLine(to: p(-11, 0))
                path.closeSubpath()
                path.move(to: p(-7, -0.5))
                path.addLine(to: p(-14, -5))
                path.addLine(to: p(-11, 0))
                path.closeSubpath()
            }

            path.move(to: p(-1.5, 4.2))
            path.addLine(to: p(2.6, 8))
            path.addLine(to: p(3.0, 3.6))
            path.closeSubpath()
        }

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
