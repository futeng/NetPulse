import Foundation
import UserNotifications

actor NotificationManager {
    private var lastSignature: String
    private var lastNotificationDate: Date?
    private var previousStatus: HealthStatus

    init() {
        let defaults = UserDefaults.standard
        lastSignature = defaults.string(forKey: "notification.lastSignature") ?? ""
        let timestamp = defaults.double(forKey: "notification.lastDate")
        lastNotificationDate = timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
        previousStatus = HealthStatus(
            rawValue: defaults.string(forKey: "notification.previousStatus") ?? ""
        ) ?? .idle
    }

    func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }

    func authorizationDescription() async -> String {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return switch settings.authorizationStatus {
        case .authorized: "通知权限已开启"
        case .provisional: "通知权限为临时允许"
        case .denied: "通知权限已关闭，请在系统设置中开启"
        case .notDetermined: "尚未选择通知权限"
        case .ephemeral: "通知权限为临时会话"
        @unknown default: "通知权限状态未知"
        }
    }

    func process(run: NetworkRun, configuration: AppConfiguration) async {
        guard configuration.notificationsEnabled else {
            previousStatus = run.status
            return
        }

        if run.status == .healthy {
            if configuration.notifyRecovery,
               previousStatus == .degraded || previousStatus == .down {
                await send(
                    title: "网络已恢复",
                    body: "\(run.results.count) 项真实访问检测全部通过。"
                )
            }
            previousStatus = run.status
            lastSignature = ""
            persistState()
            return
        }

        let failures = run.results.filter { $0.status != .healthy }
        let signature = failures
            .map { "\($0.target.id):\($0.status.rawValue)" }
            .sorted()
            .joined(separator: "|")
        let cooldown = TimeInterval(configuration.notificationCooldownMinutes * 60)
        let cooldownExpired = lastNotificationDate.map {
            Date().timeIntervalSince($0) >= cooldown
        } ?? true

        guard signature != lastSignature || cooldownExpired else {
            previousStatus = run.status
            persistState()
            return
        }

        let details = failures.prefix(3).map {
            let latency = $0.p95Ms.map { formatNotificationMilliseconds($0) } ?? "无成功样本"
            return "\($0.target.name) \($0.performanceRating.title)，P95 \(latency)"
        }.joined(separator: "；")
        await send(
            title: run.status == .down ? "网络访问失败" : "网络质量下降",
            body: "\(failures.count) 项异常：\(details)"
        )
        lastSignature = signature
        lastNotificationDate = Date()
        previousStatus = run.status
        persistState()
    }

    func sendTest() async {
        await send(title: "NetPulse 通知测试", body: "macOS 网络异常提醒工作正常。")
    }

    private func send(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func persistState() {
        let defaults = UserDefaults.standard
        defaults.set(lastSignature, forKey: "notification.lastSignature")
        defaults.set(lastNotificationDate?.timeIntervalSince1970 ?? 0, forKey: "notification.lastDate")
        defaults.set(previousStatus.rawValue, forKey: "notification.previousStatus")
    }
}

private func formatNotificationMilliseconds(_ value: Double) -> String {
    if value >= 1_000 {
        return String(format: "%.2f 秒", value / 1_000)
    }
    return "\(Int(value.rounded())) 毫秒"
}
