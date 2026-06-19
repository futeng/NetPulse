import AppKit
import Foundation
import ServiceManagement
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var configuration: AppConfiguration {
        didSet {
            guard hasLoaded else { return }
            Persistence.saveConfiguration(configuration)
            reschedule()
        }
    }
    @Published var history: [NetworkRun]
    @Published var currentRun: NetworkRun?
    @Published var isRunning = false
    @Published var selectedService = "全部"
    @Published var launchAtLoginError: String?
    @Published var notificationPermission = "正在检查通知权限"

    private var hasLoaded = false
    private var hasStarted = false
    private var scheduleTask: Task<Void, Never>?
    private let notificationManager = NotificationManager()

    init() {
        let loadedHistory = Persistence.loadHistory()
        configuration = Persistence.loadConfiguration().addingMissingBuiltInTargets()
        history = loadedHistory
        currentRun = loadedHistory.first
        hasLoaded = true
        Persistence.saveConfiguration(configuration)
        Task { [weak self] in
            self?.start()
        }
    }

    var services: [String] {
        ["全部"] + Array(Set(configuration.targets.map(\.service))).sorted()
    }

    var displayedResults: [ProbeResult] {
        guard let results = currentRun?.results else { return [] }
        if selectedService == "全部" {
            return resultsWithPinnedTargetsFirst(
                results,
                pinnedTargetIDs: Set(configuration.targets.filter(\.isPinned).map(\.id))
            )
        }
        return results.filter { $0.target.service == selectedService }
    }

    var orderedTargets: [ProbeTarget] {
        configuration.targets.enumerated()
            .sorted { left, right in
                if left.element.isPinned != right.element.isPinned {
                    return left.element.isPinned && !right.element.isPinned
                }
                return left.offset < right.offset
            }
            .map(\.element)
    }

    var overallStatus: HealthStatus {
        if isRunning { return currentRun?.status ?? .idle }
        return currentRun?.status ?? .idle
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        if configuration.notificationsEnabled {
            Task {
                await notificationManager.requestAuthorization()
                notificationPermission = await notificationManager.authorizationDescription()
            }
        }
        reschedule()
        runNow()
    }

    func runNow() {
        guard !isRunning else { return }
        isRunning = true
        let configurationSnapshot = configuration
        Task {
            let run = await ProbeEngine.run(
                targets: configurationSnapshot.targets,
                sampleCount: configurationSnapshot.sampleCount,
                timeoutSeconds: configurationSnapshot.timeoutSeconds
            )
            currentRun = run
            history.insert(run, at: 0)
            history = Array(history.prefix(50))
            Persistence.saveHistory(history)
            isRunning = false
            await notificationManager.process(run: run, configuration: configurationSnapshot)
        }
    }

    func addTarget(
        service: String,
        name: String,
        category: ProbeCategory,
        input: String,
        enabled: Bool = true,
        pinned: Bool = false
    ) {
        let normalized = normalizeURL(input)
        configuration.targets.append(
            ProbeTarget(
                service: normalizedService(service),
                name: normalizedName(name, fallback: normalized),
                category: category,
                urlString: normalized,
                acceptAnyStatusBelow500: true,
                enabled: enabled,
                isPinned: pinned
            )
        )
    }

    func updateTarget(
        _ target: ProbeTarget,
        service: String,
        name: String,
        category: ProbeCategory,
        input: String,
        enabled: Bool,
        pinned: Bool
    ) {
        guard let index = configuration.targets.firstIndex(where: { $0.id == target.id }) else {
            return
        }

        let normalized = normalizeURL(input)
        let updated = configuration.targets[index].updatingEditableFields(
            service: normalizedService(service),
            name: normalizedName(name, fallback: normalized),
            category: category,
            urlString: normalized,
            enabled: enabled,
            isPinned: pinned
        )
        configuration.targets[index] = updated

        if selectedService != "全部", !services.contains(selectedService) {
            selectedService = "全部"
        }
    }

    func deleteTarget(_ target: ProbeTarget) {
        guard !target.isBuiltIn else { return }
        configuration.targets.removeAll { $0.id == target.id }
    }

    func setTarget(_ target: ProbeTarget, enabled: Bool) {
        guard let index = configuration.targets.firstIndex(where: { $0.id == target.id }) else {
            return
        }
        configuration.targets[index].enabled = enabled
    }

    func setTarget(_ target: ProbeTarget, pinned: Bool) {
        guard let index = configuration.targets.firstIndex(where: { $0.id == target.id }) else {
            return
        }
        configuration.targets[index].isPinned = pinned
    }

    func isTargetPinned(_ targetID: UUID) -> Bool {
        configuration.targets.first(where: { $0.id == targetID })?.isPinned ?? false
    }

    func restoreBuiltIns() {
        let custom = configuration.targets.filter { !$0.isBuiltIn }
        let pinnedURLs = Set(configuration.targets.filter(\.isPinned).map(\.urlString))
        let builtIns = ProbeTarget.builtIns.map { target in
            var restored = target
            restored.isPinned = pinnedURLs.contains(target.urlString)
            return restored
        }
        configuration.targets = builtIns + custom
    }

    func importConfiguration(
        _ export: NetPulseConfigurationExport,
        mode: ConfigurationImportMode
    ) {
        switch mode {
        case .mergeTargets:
            configuration = configuration.mergingTargets(from: export)
        case .replaceConfiguration:
            configuration = configuration.replacingSharedConfiguration(with: export)
        }
    }

    func setScheduleInterval(_ minutes: Int) {
        var updated = configuration
        updated.scheduleEnabled = true
        updated.intervalMinutes = max(1, minutes)
        configuration = updated
    }

    func setScheduleEnabled(_ enabled: Bool) {
        var updated = configuration
        updated.scheduleEnabled = enabled
        configuration = updated
    }

    func testNotification() {
        Task {
            await notificationManager.requestAuthorization()
            await refreshNotificationPermission()
            await notificationManager.sendTest()
        }
    }

    func refreshNotificationPermission() async {
        notificationPermission = await notificationManager.authorizationDescription()
    }

    func openNotificationSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            configuration.launchAtLogin = enabled
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
            configuration.launchAtLogin = false
        }
    }

    private func normalizeURL(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("://") { return trimmed }
        return "https://\(trimmed)"
    }

    private func normalizedService(_ service: String) -> String {
        let trimmed = service.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "自定义" : trimmed
    }

    private func normalizedName(_ name: String, fallback: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func reschedule() {
        scheduleTask?.cancel()
        guard hasLoaded, configuration.scheduleEnabled else { return }
        let seconds = UInt64(max(1, configuration.intervalMinutes) * 60)
        scheduleTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                guard !Task.isCancelled else { return }
                self?.runNow()
            }
        }
    }
}
