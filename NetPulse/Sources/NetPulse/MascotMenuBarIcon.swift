import SwiftUI

struct MascotMenuBarIcon: View {
    let status: HealthStatus
    let isRunning: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: refreshInterval)) { timeline in
            OtterGlyph(
                status: status,
                isRunning: isRunning,
                phase: reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            )
        }
        .frame(width: 22, height: 18)
        .accessibilityLabel(Text(accessibilityLabel))
    }

    private var refreshInterval: TimeInterval {
        if reduceMotion { return 5 }
        if isRunning { return 0.12 }
        return switch status {
        case .idle: 2
        case .healthy: 1
        case .degraded: 0.4
        case .down: 2
        }
    }

    private var accessibilityLabel: String {
        isRunning ? "NetPulse 正在检测网络" : "NetPulse 网络\(status.title)"
    }
}

private struct OtterGlyph: View {
    let status: HealthStatus
    let isRunning: Bool
    let phase: TimeInterval

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 22, size.height / 18)
            context.scaleBy(x: scale, y: scale)

            let bob = bodyBob
            drawTail(in: &context, bob: bob)
            drawBody(in: &context, bob: bob)
            drawHead(in: &context, bob: bob)
            drawPulseOrb(in: &context, bob: bob)
        }
    }

    private var bodyBob: CGFloat {
        guard isRunning else { return 0 }
        return CGFloat(sin(phase * 12)) * 0.45
    }

    private var tailTip: CGPoint {
        if isRunning {
            return CGPoint(
                x: 17.8 + CGFloat(cos(phase * 10)) * 1.6,
                y: 8.5 + CGFloat(sin(phase * 10)) * 3.2
            )
        }
        switch status {
        case .healthy:
            return CGPoint(x: 18.5, y: 7.4 + CGFloat(sin(phase * 1.4)) * 0.8)
        case .degraded:
            return CGPoint(x: 18.2, y: 8.8 + CGFloat(sin(phase * 5.5)) * 2)
        case .down:
            return CGPoint(x: 17.2, y: 14.8)
        case .idle:
            return CGPoint(x: 18, y: 9.5)
        }
    }

    private func drawTail(in context: inout GraphicsContext, bob: CGFloat) {
        var tail = Path()
        tail.move(to: CGPoint(x: 6.6, y: 13.4 + bob))
        tail.addCurve(
            to: tailTip,
            control1: CGPoint(x: 10.5, y: 17.2 + bob),
            control2: CGPoint(x: 18.8, y: 15.2)
        )
        context.stroke(
            tail,
            with: .color(.primary),
            style: StrokeStyle(lineWidth: 2.4, lineCap: .round)
        )
    }

    private func drawBody(in context: inout GraphicsContext, bob: CGFloat) {
        let body = Path(
            ellipseIn: CGRect(x: 4.2, y: 6 + bob, width: 10.5, height: 10.5)
        )
        context.stroke(body, with: .color(.primary), lineWidth: 1.5)
    }

    private func drawHead(in context: inout GraphicsContext, bob: CGFloat) {
        let headRect = CGRect(x: 4.8, y: 1.4 + bob, width: 9, height: 8)
        context.fill(
            Path(ellipseIn: CGRect(x: 4.7, y: 1 + bob, width: 2.5, height: 2.5)),
            with: .color(.primary)
        )
        context.fill(
            Path(ellipseIn: CGRect(x: 11.4, y: 1 + bob, width: 2.5, height: 2.5)),
            with: .color(.primary)
        )
        context.fill(Path(ellipseIn: headRect), with: .color(.primary))

        let eyeColor = Color(nsColor: .windowBackgroundColor)
        context.fill(
            Path(ellipseIn: CGRect(x: 7.1, y: 4.2 + bob, width: 1.1, height: 1.1)),
            with: .color(eyeColor)
        )
        context.fill(
            Path(ellipseIn: CGRect(x: 10.5, y: 4.2 + bob, width: 1.1, height: 1.1)),
            with: .color(eyeColor)
        )
        context.fill(
            Path(ellipseIn: CGRect(x: 8.65, y: 5.8 + bob, width: 1.4, height: 1)),
            with: .color(eyeColor)
        )
    }

    private func drawPulseOrb(in context: inout GraphicsContext, bob: CGFloat) {
        let center = CGPoint(x: 9.3, y: 11.8 + bob)
        let orb = Path(ellipseIn: CGRect(x: center.x - 2.4, y: center.y - 2.4, width: 4.8, height: 4.8))
        context.fill(orb, with: .color(orbColor))

        var pulse = Path()
        if status == .down && !isRunning {
            pulse.move(to: CGPoint(x: center.x - 0.9, y: center.y - 0.9))
            pulse.addLine(to: CGPoint(x: center.x + 0.9, y: center.y + 0.9))
            pulse.move(to: CGPoint(x: center.x + 0.9, y: center.y - 0.9))
            pulse.addLine(to: CGPoint(x: center.x - 0.9, y: center.y + 0.9))
        } else {
            pulse.move(to: CGPoint(x: center.x - 1.7, y: center.y))
            pulse.addLine(to: CGPoint(x: center.x - 0.7, y: center.y))
            pulse.addLine(to: CGPoint(x: center.x - 0.2, y: center.y - 1))
            pulse.addLine(to: CGPoint(x: center.x + 0.45, y: center.y + 1))
            pulse.addLine(to: CGPoint(x: center.x + 0.9, y: center.y))
            pulse.addLine(to: CGPoint(x: center.x + 1.7, y: center.y))
        }
        context.stroke(
            pulse,
            with: .color(Color(nsColor: .windowBackgroundColor)),
            style: StrokeStyle(lineWidth: 0.65, lineCap: .round, lineJoin: .round)
        )
    }

    private var orbColor: Color {
        if isRunning { return .cyan }
        return switch status {
        case .idle: .secondary
        case .healthy: .green
        case .degraded: .orange
        case .down: .red
        }
    }
}
