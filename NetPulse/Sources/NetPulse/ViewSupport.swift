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

    var body: some View {
        ZStack {
            Circle()
                .fill(statusColor(status).opacity(0.14))
            Image(systemName: isRunning ? "waveform.path.ecg" : statusSymbol(status))
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(statusColor(status))
        }
        .frame(width: 48, height: 48)
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
