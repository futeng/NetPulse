import AppKit
import Combine

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let model: AppModel
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private var timer: Timer?
    private var cancellable: AnyCancellable?
    private var phase = 0.0
    private var timerInterval: TimeInterval = 0.25

    init(model: AppModel) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: 28)
        super.init()

        menu.delegate = self
        statusItem.menu = menu
        if let button = statusItem.button {
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyUpOrDown
            button.title = ""
            button.setAccessibilityLabel("NetPulse")
            button.setAccessibilityRole(.menuButton)
        }

        updateStatusItem()
        restartTimerIfNeeded()

        cancellable = model.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateStatusItem()
                self?.restartTimerIfNeeded()
            }
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    @objc private func runNow() {
        model.runNow()
        updateStatusItem()
    }

    @objc private func openDashboard() {
        if let url = URL(string: "netpulse://dashboard") {
            NSWorkspace.shared.open(url)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func selectRunner(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let runner = MenuBarRunner(rawValue: rawValue)
        else {
            return
        }

        model.setMenuBarRunner(runner)
        updateStatusItem()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func timerFired() {
        updateStatusItem()
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let statusTitle = model.isRunning ? "检测中" : model.menuBarStatus.title
        let statusItem = NSMenuItem(title: "\(statusTitle)  \(currentTimeText)", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        if let run = model.currentRun {
            let summary = "健康 \(run.healthyCount)/\(run.results.count) · 可用 \(run.availableCount)/\(run.results.count)"
            let summaryItem = NSMenuItem(title: summary, action: nil, keyEquivalent: "")
            summaryItem.isEnabled = false
            menu.addItem(summaryItem)
        }

        if let score = model.menuBarNetworkScore {
            let scoreItem = NSMenuItem(
                title: "体验分 \(Int(score.rounded()))/100 · \(model.menuBarNetworkPace.accessibilityDescription)",
                action: nil,
                keyEquivalent: ""
            )
            scoreItem.isEnabled = false
            menu.addItem(scoreItem)
        }

        menu.addItem(.separator())

        let runItem = NSMenuItem(title: "立即检测", action: #selector(runNow), keyEquivalent: "r")
        runItem.target = self
        runItem.isEnabled = !model.isRunning
        menu.addItem(runItem)

        let dashboardItem = NSMenuItem(title: "打开面板", action: #selector(openDashboard), keyEquivalent: "")
        dashboardItem.target = self
        menu.addItem(dashboardItem)

        let runnerItem = NSMenuItem(title: "菜单栏形象", action: nil, keyEquivalent: "")
        let runnerMenu = NSMenu()
        for runner in MenuBarRunner.allCases {
            let item = NSMenuItem(title: runner.title, action: #selector(selectRunner), keyEquivalent: "")
            item.target = self
            item.representedObject = runner.rawValue
            item.state = runner == model.configuration.menuBarRunner ? .on : .off
            runnerMenu.addItem(item)
        }
        runnerItem.submenu = runnerMenu
        menu.addItem(runnerItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出 NetPulse", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func updateStatusItem() {
        let pace = model.menuBarNetworkPace
        let motion = pace.motion
        let phaseStep = motion.frameInterval / max(0.2, motion.cycleSeconds)
        phase = (phase + phaseStep).truncatingRemainder(dividingBy: 1)
        statusItem.button?.image = MenuBarIconRenderer.image(
            for: pace,
            runner: model.configuration.menuBarRunner,
            phase: phase
        )
        statusItem.button?.title = ""
        let scoreText = model.menuBarNetworkScore
            .map { " · 体验分 \(Int($0.rounded()))/100" } ?? ""
        statusItem.button?.toolTip = "NetPulse · \(model.configuration.menuBarRunner.title) · \(model.menuBarStatus.title)\(scoreText) · \(pace.accessibilityDescription)"
        statusItem.button?.setAccessibilityLabel("NetPulse \(model.menuBarStatus.title)")
        statusItem.length = 34
    }

    private func restartTimerIfNeeded() {
        let interval = model.menuBarNetworkPace.frameInterval
        guard abs(interval - timerInterval) > 0.001 || timer == nil else { return }
        timerInterval = interval
        timer?.invalidate()
        let timer = Timer(
            timeInterval: interval,
            target: self,
            selector: #selector(timerFired),
            userInfo: nil,
            repeats: true
        )
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private var currentTimeText: String {
        Date().formatted(date: .omitted, time: .shortened)
    }
}

enum MenuBarIconRenderer {
    static func image(
        for pace: MenuBarNetworkPace,
        runner: MenuBarRunner,
        phase: Double
    ) -> NSImage {
        let size = NSSize(width: 32, height: 20)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        let motion = pace.motion
        let stride = motion.isStalled ? stalledStride(phase) : smoothStride(phase)
        let wobble = sin(phase * 2 * .pi * motion.wobbleRate) * motion.wobble
        let blink = motion.shouldBlink ? 0.42 + smoothStride(phase) * 0.58 : 1
        let alpha = pace.templateAlpha * blink

        switch runner {
        case .tropicalFish, .clownFish, .arowana, .bettaFish, .goldfish,
             .guppy, .neonTetra, .angelfish, .pufferFish:
            drawSignalWake(
                pace: pace,
                alpha: pace.templateAlpha,
                stride: stride,
                travel: motion.travel,
                wobble: wobble,
                canvas: size
            )
            drawFish(
                runner: runner,
                pace: pace,
                alpha: alpha,
                stride: stride,
                travel: motion.travel,
                wobble: wobble,
                phase: phase,
                motion: motion,
                canvas: size
            )
        case .signalShuttle:
            drawTrails(
                pace: pace,
                alpha: pace.templateAlpha,
                stride: stride,
                travel: motion.travel,
                wobble: wobble
            )
            drawShuttle(
                alpha: alpha,
                stride: stride,
                travel: motion.travel,
                wobble: wobble,
                motion: motion,
                canvas: size
            )
        }

        image.isTemplate = true
        return image
    }

    private static func drawSignalWake(
        pace: MenuBarNetworkPace,
        alpha: Double,
        stride: Double,
        travel: Double,
        wobble: Double,
        canvas: NSSize
    ) {
        guard pace != .idle && pace != .unavailable else { return }

        for index in 0..<3 {
            let progress = (stride + Double(index) * 0.28).truncatingRemainder(dividingBy: 1)
            let x = canvas.width / 2 - 12.2 - Double(index) * 1.5 + travel * stride * 0.08
            let y = canvas.height / 2 - 2.4 - wobble * 0.12
            let width = 5.0 + Double(index) * 2.2 + progress * 1.2
            let height = 4.2 + Double(index) * 1.0
            let waveAlpha = alpha * max(0.12, 0.42 - Double(index) * 0.1) * (1 - progress * 0.45)

            NSColor.black.withAlphaComponent(waveAlpha).setStroke()
            let wave = NSBezierPath()
            wave.lineWidth = 1.15
            wave.lineCapStyle = .round
            wave.appendArc(
                withCenter: NSPoint(x: x, y: y + height / 2),
                radius: width / 2,
                startAngle: -42,
                endAngle: 42,
                clockwise: false
            )
            wave.stroke()
        }
    }

    private static func drawTrails(
        pace: MenuBarNetworkPace,
        alpha: Double,
        stride: Double,
        travel: Double,
        wobble: Double
    ) {
        guard pace != .idle && pace != .unavailable else { return }
        for index in 0..<3 {
            let baseAlpha = max(0.12, 0.42 - Double(index) * 0.11)
            let trailAlpha = alpha * baseAlpha * (0.55 + stride * 0.45)
            let width = max(1, 8.5 - Double(index) * 2.3 + stride * 1.4)
            let height = max(1.0, 2.2 - Double(index) * 0.45)
            let x = 4.4 - Double(index) * 2.1 + travel * stride * 0.18
            let y = 3.0 + wobble * 0.18

            NSColor.black.withAlphaComponent(trailAlpha).setFill()
            NSBezierPath(
                roundedRect: NSRect(x: x, y: y, width: width, height: height),
                xRadius: height / 2,
                yRadius: height / 2
            )
            .fill()
        }
    }

    private static func drawFish(
        runner: MenuBarRunner,
        pace: MenuBarNetworkPace,
        alpha: Double,
        stride: Double,
        travel: Double,
        wobble: Double,
        phase: Double,
        motion: IconMotion,
        canvas: NSSize
    ) {
        if pace == .unavailable {
            drawRestingFish(runner: runner, alpha: alpha, phase: phase, canvas: canvas)
            return
        }

        let tailBeat = sin(phase * 4 * .pi)
        let glide = sin(phase * 2 * .pi - .pi / 2)
        let center = NSPoint(
            x: canvas.width / 2 + travel * stride - travel / 2,
            y: canvas.height / 2 - wobble * 0.08 + glide * 0.45
        )
        let scale = 1 + stride * motion.scale
        let tilt = motion.tilt * 0.15 + glide * 2.4 + wobble * 0.08

        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: center.x, yBy: center.y)
        transform.rotate(byDegrees: tilt)
        transform.scale(by: CGFloat(scale))
        transform.concat()

        NSColor.black.withAlphaComponent(alpha).setFill()
        drawFishBody(runner: runner)
        drawFishTail(runner: runner, alpha: alpha, tailBeat: tailBeat)
        drawFishFins(runner: runner, alpha: alpha)
        drawFishDetails(runner: runner, alpha: alpha)

        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawFishBody(runner: MenuBarRunner) {
        let body = NSBezierPath()
        switch runner {
        case .arowana:
            body.move(to: NSPoint(x: 12.6, y: 0.4))
            body.curve(
                to: NSPoint(x: -10.8, y: 2.7),
                controlPoint1: NSPoint(x: 7.8, y: 3.3),
                controlPoint2: NSPoint(x: -4.2, y: 3.7)
            )
            body.curve(
                to: NSPoint(x: -12.2, y: -1.2),
                controlPoint1: NSPoint(x: -12.2, y: 1.4),
                controlPoint2: NSPoint(x: -12.8, y: 0.0)
            )
            body.curve(
                to: NSPoint(x: 10.8, y: -2.0),
                controlPoint1: NSPoint(x: -5.6, y: -3.4),
                controlPoint2: NSPoint(x: 6.0, y: -2.9)
            )
            body.line(to: NSPoint(x: 13.1, y: -0.8))
            body.line(to: NSPoint(x: 12.6, y: 0.4))
            body.close()
        case .bettaFish:
            body.move(to: NSPoint(x: 8.8, y: 0))
            body.curve(
                to: NSPoint(x: -4.5, y: 4.2),
                controlPoint1: NSPoint(x: 4.8, y: 5.1),
                controlPoint2: NSPoint(x: -1.5, y: 5.1)
            )
            body.curve(
                to: NSPoint(x: -4.8, y: -4.2),
                controlPoint1: NSPoint(x: -7.0, y: 2.1),
                controlPoint2: NSPoint(x: -7.0, y: -2.1)
            )
            body.curve(
                to: NSPoint(x: 8.8, y: 0),
                controlPoint1: NSPoint(x: -1.5, y: -5.1),
                controlPoint2: NSPoint(x: 4.8, y: -5.1)
            )
            body.close()
        case .goldfish:
            body.appendOval(in: NSRect(x: -7.0, y: -5.9, width: 16.0, height: 11.8))
            body.move(to: NSPoint(x: 8.0, y: 0))
            body.line(to: NSPoint(x: 11.2, y: 1.1))
            body.line(to: NSPoint(x: 11.2, y: -1.1))
            body.close()
        case .guppy:
            body.move(to: NSPoint(x: 9.5, y: 0))
            body.curve(
                to: NSPoint(x: -4.8, y: 3.5),
                controlPoint1: NSPoint(x: 5.5, y: 4.0),
                controlPoint2: NSPoint(x: -1.5, y: 4.2)
            )
            body.curve(
                to: NSPoint(x: -4.8, y: -3.5),
                controlPoint1: NSPoint(x: -6.8, y: 1.8),
                controlPoint2: NSPoint(x: -6.8, y: -1.8)
            )
            body.curve(
                to: NSPoint(x: 9.5, y: 0),
                controlPoint1: NSPoint(x: -1.5, y: -4.2),
                controlPoint2: NSPoint(x: 5.5, y: -4.0)
            )
            body.close()
        case .neonTetra:
            body.move(to: NSPoint(x: 11.0, y: 0))
            body.curve(
                to: NSPoint(x: -8.4, y: 2.7),
                controlPoint1: NSPoint(x: 5.4, y: 3.4),
                controlPoint2: NSPoint(x: -2.8, y: 3.5)
            )
            body.curve(
                to: NSPoint(x: -8.4, y: -2.7),
                controlPoint1: NSPoint(x: -10.4, y: 1.2),
                controlPoint2: NSPoint(x: -10.4, y: -1.2)
            )
            body.curve(
                to: NSPoint(x: 11.0, y: 0),
                controlPoint1: NSPoint(x: -2.8, y: -3.5),
                controlPoint2: NSPoint(x: 5.4, y: -3.4)
            )
            body.close()
        case .angelfish:
            body.move(to: NSPoint(x: 8.8, y: 0))
            body.line(to: NSPoint(x: 0.4, y: 7.8))
            body.line(to: NSPoint(x: -7.4, y: 0))
            body.line(to: NSPoint(x: 0.4, y: -7.8))
            body.close()
        case .pufferFish:
            body.appendOval(in: NSRect(x: -7.8, y: -6.7, width: 15.8, height: 13.4))
            body.move(to: NSPoint(x: 8.0, y: 0))
            body.line(to: NSPoint(x: 11.2, y: 1.3))
            body.line(to: NSPoint(x: 11.2, y: -1.3))
            body.close()
        case .clownFish:
            body.move(to: NSPoint(x: 10.2, y: 0))
            body.curve(to: NSPoint(x: -7.2, y: 4.7), controlPoint1: NSPoint(x: 5.9, y: 5.8), controlPoint2: NSPoint(x: -2.8, y: 6.0))
            body.curve(to: NSPoint(x: -7.6, y: -4.7), controlPoint1: NSPoint(x: -9.9, y: 2.2), controlPoint2: NSPoint(x: -9.9, y: -2.2))
            body.curve(to: NSPoint(x: 10.2, y: 0), controlPoint1: NSPoint(x: -2.8, y: -6.0), controlPoint2: NSPoint(x: 6.0, y: -5.8))
            body.close()
        default:
            body.move(to: NSPoint(x: 11.5, y: 0))
            body.curve(to: NSPoint(x: -7.0, y: 5.0), controlPoint1: NSPoint(x: 6.2, y: 5.9), controlPoint2: NSPoint(x: -1.8, y: 6.3))
            body.curve(to: NSPoint(x: -7.0, y: -5.0), controlPoint1: NSPoint(x: -10.0, y: 2.5), controlPoint2: NSPoint(x: -10.0, y: -2.5))
            body.curve(to: NSPoint(x: 11.5, y: 0), controlPoint1: NSPoint(x: -1.8, y: -6.3), controlPoint2: NSPoint(x: 6.2, y: -5.9))
            body.close()
        }
        body.fill()
    }

    private static func drawFishTail(runner: MenuBarRunner, alpha: Double, tailBeat: Double) {
        NSColor.black.withAlphaComponent(alpha * 0.92).setFill()
        let tailOffset = tailBeat * 1.5
        switch runner {
        case .arowana:
            drawForkTail(rootX: -11.2, tipX: -15.8, amplitude: 2.8, tailOffset: tailOffset)
            return
        case .bettaFish:
            drawFanTail(rootX: -4.8, tipX: -15.8, height: 8.5, tailOffset: tailOffset)
            return
        case .goldfish:
            drawDoubleRoundTail(rootX: -6.8, tipX: -14.5, height: 6.6, tailOffset: tailOffset)
            return
        case .guppy:
            drawFanTail(rootX: -4.8, tipX: -14.8, height: 6.8, tailOffset: tailOffset)
            return
        case .neonTetra:
            drawForkTail(rootX: -8.2, tipX: -13.4, amplitude: 3.4, tailOffset: tailOffset)
            return
        default:
            break
        }

        let upperTail = NSBezierPath()
        upperTail.move(to: NSPoint(x: -7.0, y: 0.6))
        upperTail.line(to: NSPoint(x: -13.4, y: 5.0 + tailOffset))
        upperTail.line(to: NSPoint(x: -11.5, y: 0.4 + tailOffset * 0.35))
        upperTail.close()
        upperTail.fill()

        let lowerTail = NSBezierPath()
        lowerTail.move(to: NSPoint(x: -7.0, y: -0.6))
        lowerTail.line(to: NSPoint(x: -13.4, y: -5.0 + tailOffset))
        lowerTail.line(to: NSPoint(x: -11.5, y: -0.4 + tailOffset * 0.35))
        lowerTail.close()
        lowerTail.fill()
    }

    private static func drawForkTail(
        rootX: Double,
        tipX: Double,
        amplitude: Double,
        tailOffset: Double
    ) {
        let upperTail = NSBezierPath()
        upperTail.move(to: NSPoint(x: rootX, y: 0.5))
        upperTail.line(to: NSPoint(x: tipX, y: amplitude + tailOffset))
        upperTail.line(to: NSPoint(x: tipX + 2.8, y: 0.4 + tailOffset * 0.25))
        upperTail.close()
        upperTail.fill()

        let lowerTail = NSBezierPath()
        lowerTail.move(to: NSPoint(x: rootX, y: -0.5))
        lowerTail.line(to: NSPoint(x: tipX, y: -amplitude + tailOffset))
        lowerTail.line(to: NSPoint(x: tipX + 2.8, y: -0.4 + tailOffset * 0.25))
        lowerTail.close()
        lowerTail.fill()
    }

    private static func drawFanTail(
        rootX: Double,
        tipX: Double,
        height: Double,
        tailOffset: Double
    ) {
        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: rootX, y: 0))
        tail.curve(
            to: NSPoint(x: tipX, y: height / 2 + tailOffset),
            controlPoint1: NSPoint(x: rootX - 3.4, y: 2.2),
            controlPoint2: NSPoint(x: tipX + 2.2, y: height / 2)
        )
        tail.curve(
            to: NSPoint(x: tipX, y: -height / 2 + tailOffset),
            controlPoint1: NSPoint(x: tipX - 1.0, y: 1.6),
            controlPoint2: NSPoint(x: tipX - 1.0, y: -1.6)
        )
        tail.curve(
            to: NSPoint(x: rootX, y: 0),
            controlPoint1: NSPoint(x: tipX + 2.2, y: -height / 2),
            controlPoint2: NSPoint(x: rootX - 3.4, y: -2.2)
        )
        tail.close()
        tail.fill()
    }

    private static func drawDoubleRoundTail(
        rootX: Double,
        tipX: Double,
        height: Double,
        tailOffset: Double
    ) {
        NSBezierPath(
            ovalIn: NSRect(
                x: tipX,
                y: 0.2 + tailOffset,
                width: abs(tipX - rootX) + 1.5,
                height: height / 2
            )
        )
        .fill()
        NSBezierPath(
            ovalIn: NSRect(
                x: tipX,
                y: -height / 2 - 0.2 + tailOffset,
                width: abs(tipX - rootX) + 1.5,
                height: height / 2
            )
        )
        .fill()
    }

    private static func drawFishFins(runner: MenuBarRunner, alpha: Double) {
        NSColor.black.withAlphaComponent(alpha * 0.74).setFill()

        let topFin = NSBezierPath()
        switch runner {
        case .arowana:
            topFin.move(to: NSPoint(x: -4.8, y: 2.4))
            topFin.line(to: NSPoint(x: 5.0, y: 4.4))
            topFin.line(to: NSPoint(x: 6.0, y: 1.7))
        case .bettaFish:
            topFin.move(to: NSPoint(x: -2.3, y: 4.0))
            topFin.curve(
                to: NSPoint(x: 4.4, y: 8.8),
                controlPoint1: NSPoint(x: -0.8, y: 7.6),
                controlPoint2: NSPoint(x: 2.8, y: 9.8)
            )
            topFin.line(to: NSPoint(x: 3.6, y: 3.6))
        case .goldfish:
            topFin.move(to: NSPoint(x: -1.8, y: 4.8))
            topFin.line(to: NSPoint(x: 2.4, y: 7.4))
            topFin.line(to: NSPoint(x: 2.8, y: 4.4))
        case .guppy:
            topFin.move(to: NSPoint(x: -1.3, y: 3.2))
            topFin.line(to: NSPoint(x: 2.2, y: 5.6))
            topFin.line(to: NSPoint(x: 3.0, y: 3.0))
        case .neonTetra:
            topFin.move(to: NSPoint(x: -1.5, y: 2.4))
            topFin.line(to: NSPoint(x: 1.6, y: 4.7))
            topFin.line(to: NSPoint(x: 2.2, y: 2.2))
        case .angelfish:
            topFin.move(to: NSPoint(x: -1.2, y: 5.6))
            topFin.line(to: NSPoint(x: 3.5, y: 9.6))
            topFin.line(to: NSPoint(x: 4.1, y: 3.2))
        case .pufferFish:
            topFin.move(to: NSPoint(x: -2.4, y: 5.5))
            topFin.line(to: NSPoint(x: 1.8, y: 8.0))
            topFin.line(to: NSPoint(x: 2.4, y: 5.0))
        default:
            topFin.move(to: NSPoint(x: -1.8, y: 4.4))
            topFin.line(to: NSPoint(x: 2.6, y: 7.9))
            topFin.line(to: NSPoint(x: 3.1, y: 3.7))
        }
        topFin.close()
        topFin.fill()

        let bottomFin = NSBezierPath()
        bottomFin.move(to: NSPoint(x: 0.4, y: -3.0))
        bottomFin.line(to: NSPoint(x: 4.3, y: -6.4))
        bottomFin.line(to: NSPoint(x: 3.0, y: -2.1))
        bottomFin.close()
        bottomFin.fill()
    }

    private static func drawFishDetails(runner: MenuBarRunner, alpha: Double) {
        let detail = NSBezierPath()
        detail.lineWidth = 1.1
        detail.lineCapStyle = .round

        switch runner {
        case .arowana:
            detail.lineWidth = 0.9
            detail.move(to: NSPoint(x: -6.5, y: 0.7))
            detail.line(to: NSPoint(x: 8.0, y: 0.1))
            detail.move(to: NSPoint(x: 4.5, y: 1.2))
            detail.line(to: NSPoint(x: 5.6, y: -1.2))
            detail.move(to: NSPoint(x: 8.2, y: 1.0))
            detail.line(to: NSPoint(x: 9.1, y: -1.0))
        case .bettaFish:
            detail.move(to: NSPoint(x: -7.2, y: 5.1))
            detail.curve(
                to: NSPoint(x: -7.0, y: -5.0),
                controlPoint1: NSPoint(x: -10.0, y: 2.6),
                controlPoint2: NSPoint(x: -10.0, y: -2.6)
            )
            detail.move(to: NSPoint(x: 1.8, y: 4.0))
            detail.line(to: NSPoint(x: 1.2, y: -4.0))
        case .goldfish:
            detail.move(to: NSPoint(x: -1.2, y: 4.5))
            detail.line(to: NSPoint(x: -2.2, y: -4.5))
            detail.move(to: NSPoint(x: 3.5, y: 3.4))
            detail.line(to: NSPoint(x: 2.6, y: -3.4))
        case .guppy:
            detail.move(to: NSPoint(x: -5.6, y: 3.4))
            detail.line(to: NSPoint(x: -5.8, y: -3.4))
            detail.move(to: NSPoint(x: 3.0, y: 2.8))
            detail.line(to: NSPoint(x: 2.2, y: -2.8))
        case .neonTetra:
            detail.lineWidth = 0.9
            detail.move(to: NSPoint(x: -7.2, y: 0.8))
            detail.line(to: NSPoint(x: 7.5, y: 0.6))
            detail.move(to: NSPoint(x: -1.5, y: -0.8))
            detail.line(to: NSPoint(x: 8.6, y: -0.6))
        case .clownFish:
            detail.move(to: NSPoint(x: 3.6, y: 4.0))
            detail.line(to: NSPoint(x: 2.3, y: -4.0))
            detail.move(to: NSPoint(x: -2.8, y: 4.5))
            detail.line(to: NSPoint(x: -3.9, y: -4.3))
        case .angelfish:
            detail.move(to: NSPoint(x: 1.8, y: 5.0))
            detail.line(to: NSPoint(x: 1.8, y: -5.0))
        case .pufferFish:
            detail.move(to: NSPoint(x: -3.0, y: 3.4))
            detail.line(to: NSPoint(x: -1.8, y: 2.1))
            detail.move(to: NSPoint(x: -4.0, y: -1.8))
            detail.line(to: NSPoint(x: -2.5, y: -3.0))
        default:
            detail.move(to: NSPoint(x: 0.2, y: 4.5))
            detail.line(to: NSPoint(x: -1.0, y: -4.5))
            detail.move(to: NSPoint(x: 4.0, y: 3.2))
            detail.line(to: NSPoint(x: 3.0, y: -3.2))
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.cgContext.setBlendMode(.clear)
        NSColor.clear.setStroke()
        detail.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawRestingFish(
        runner: MenuBarRunner,
        alpha: Double,
        phase: Double,
        canvas: NSSize
    ) {
        let breathe = 0.88 + 0.12 * smoothStride(phase)
        let center = NSPoint(
            x: canvas.width / 2,
            y: canvas.height / 2
        )

        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: center.x, yBy: center.y)
        transform.rotate(byDegrees: -4)
        transform.scale(by: CGFloat(breathe))
        transform.concat()

        NSColor.black.withAlphaComponent(alpha * 0.9).setFill()
        drawFishBody(runner: runner)
        drawFishTail(runner: runner, alpha: alpha * 0.85, tailBeat: 0.2)
        drawFishFins(runner: runner, alpha: alpha * 0.8)
        drawFishDetails(runner: runner, alpha: alpha * 0.7)

        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawConnectionSpark(alpha: Double, wobble: Double) {
        NSColor.black.withAlphaComponent(alpha).setStroke()
        let spark = NSBezierPath()
        spark.lineWidth = 1.3
        spark.lineCapStyle = .round
        spark.move(to: NSPoint(x: 8.6, y: 4.7))
        spark.line(to: NSPoint(x: 10.4, y: 4.7 + wobble * 0.05))
        spark.move(to: NSPoint(x: 9.4, y: 3.6))
        spark.line(to: NSPoint(x: 11.1, y: 2.7 + wobble * 0.04))
        spark.stroke()
    }

    private static func drawShuttle(
        alpha: Double,
        stride: Double,
        travel: Double,
        wobble: Double,
        motion: IconMotion,
        canvas: NSSize
    ) {
        let center = NSPoint(
            x: canvas.width / 2 + travel * stride - travel / 2,
            y: canvas.height / 2 - wobble * 0.25
        )

        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: center.x, yBy: center.y)
        transform.rotate(byDegrees: motion.tilt + wobble)
        transform.scale(by: CGFloat(1 + stride * motion.scale))
        transform.concat()

        NSColor.black.withAlphaComponent(alpha).setFill()
        let body = NSBezierPath()
        body.move(to: NSPoint(x: 8.2, y: 0))
        body.line(to: NSPoint(x: -7.2, y: 5.2))
        body.line(to: NSPoint(x: -4.4, y: 0.6))
        body.line(to: NSPoint(x: -7.2, y: -5.2))
        body.close()
        body.fill()

        NSColor.black.withAlphaComponent(alpha * 0.72).setFill()
        NSBezierPath(ovalIn: NSRect(x: -1.8, y: -1.8, width: 3.6, height: 3.6)).fill()

        if motion.shouldBlink {
            NSColor.black.withAlphaComponent(alpha * 0.85).setStroke()
            let slash = NSBezierPath()
            slash.lineWidth = 1.4
            slash.lineCapStyle = .round
            slash.move(to: NSPoint(x: -5.3, y: 5.3))
            slash.line(to: NSPoint(x: 5.3, y: -5.3))
            slash.stroke()
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func smoothStride(_ phase: Double) -> Double {
        (sin(phase * 2 * .pi - .pi / 2) + 1) / 2
    }

    private static func stalledStride(_ phase: Double) -> Double {
        let stepped = floor(phase * 5) / 4
        return min(1, max(0, stepped))
    }
}

struct IconMotion {
    var cycleSeconds: Double
    var frameInterval: TimeInterval
    var travel: Double
    var wobble: Double
    var wobbleRate: Double
    var scale: Double
    var tilt: Double
    var isStalled: Bool
    var shouldBlink: Bool
}

extension MenuBarNetworkPace {
    var frameInterval: TimeInterval { motion.frameInterval }

    var accessibilityDescription: String {
        switch self {
        case .idle:
            return "尚未检测"
        case .excellent:
            return "轻快巡游"
        case .good:
            return "平稳巡游"
        case .slow:
            return "悠闲慢游"
        case .verySlow:
            return "缓慢漂游"
        case .unstable:
            return "低速巡游"
        case .unavailable:
            return "原地休息"
        case .checking:
            return "正在快速巡游检测"
        }
    }

    var templateAlpha: Double {
        switch self {
        case .idle:
            return 0.42
        case .excellent, .good:
            return 0.94
        case .slow, .verySlow, .unstable, .checking:
            return 0.86
        case .unavailable:
            return 0.9
        }
    }

    var motion: IconMotion {
        switch self {
        case .checking:
            return IconMotion(cycleSeconds: 0.46, frameInterval: 0.07, travel: 7.4, wobble: 1.1, wobbleRate: 1.2, scale: 0.06, tilt: -8, isStalled: false, shouldBlink: false)
        case .excellent:
            return IconMotion(cycleSeconds: 0.9, frameInterval: 0.09, travel: 6.4, wobble: 0.45, wobbleRate: 1, scale: 0.035, tilt: -5, isStalled: false, shouldBlink: false)
        case .good:
            return IconMotion(cycleSeconds: 1.45, frameInterval: 0.12, travel: 5.2, wobble: 0.42, wobbleRate: 1, scale: 0.03, tilt: -4, isStalled: false, shouldBlink: false)
        case .slow:
            return IconMotion(cycleSeconds: 2.25, frameInterval: 0.16, travel: 3.8, wobble: 0.35, wobbleRate: 0.9, scale: 0.02, tilt: -3, isStalled: false, shouldBlink: false)
        case .verySlow:
            return IconMotion(cycleSeconds: 3.35, frameInterval: 0.22, travel: 2.4, wobble: 0.3, wobbleRate: 0.85, scale: 0.015, tilt: -2, isStalled: false, shouldBlink: false)
        case .unstable:
            return IconMotion(cycleSeconds: 4.1, frameInterval: 0.26, travel: 1.7, wobble: 0.26, wobbleRate: 0.75, scale: 0.012, tilt: -1, isStalled: false, shouldBlink: false)
        case .unavailable:
            return IconMotion(cycleSeconds: 4.6, frameInterval: 0.32, travel: 0.6, wobble: 0.16, wobbleRate: 0.65, scale: 0.01, tilt: 0, isStalled: false, shouldBlink: false)
        case .idle:
            return IconMotion(cycleSeconds: 4.0, frameInterval: 0.32, travel: 1.0, wobble: 0.16, wobbleRate: 0.75, scale: 0.01, tilt: -1, isStalled: false, shouldBlink: false)
        }
    }
}
