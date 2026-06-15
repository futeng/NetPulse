import SwiftUI

struct NetworkPulseMenuBarIcon: View {
    let status: HealthStatus
    let isRunning: Bool

    var body: some View {
        Image(systemName: symbolName)
        .font(.system(size: 15, weight: .semibold))
        .frame(width: 20, height: 18)
        .accessibilityLabel(Text(accessibilityLabel))
    }

    private var symbolName: String {
        if isRunning { return "arrow.triangle.2.circlepath" }
        return switch status {
        case .idle: "network"
        case .healthy: "dot.radiowaves.left.and.right"
        case .degraded: "exclamationmark.triangle"
        case .down: "wifi.slash"
        }
    }

    private var accessibilityLabel: String {
        isRunning ? "NetPulse 正在检测网络" : "NetPulse 网络\(status.title)"
    }
}
