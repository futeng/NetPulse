import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct SharedRuntimeSettings: Codable, Equatable {
    var scheduleEnabled: Bool
    var intervalMinutes: Int
    var sampleCount: Int
    var timeoutSeconds: Double
    var notificationsEnabled: Bool
    var notifyRecovery: Bool
    var notificationCooldownMinutes: Int

    init(configuration: AppConfiguration) {
        scheduleEnabled = configuration.scheduleEnabled
        intervalMinutes = configuration.intervalMinutes
        sampleCount = configuration.sampleCount
        timeoutSeconds = configuration.timeoutSeconds
        notificationsEnabled = configuration.notificationsEnabled
        notifyRecovery = configuration.notifyRecovery
        notificationCooldownMinutes = configuration.notificationCooldownMinutes
    }

    func applied(to configuration: AppConfiguration) -> AppConfiguration {
        var updated = configuration
        updated.scheduleEnabled = scheduleEnabled
        updated.intervalMinutes = max(1, intervalMinutes)
        updated.sampleCount = max(1, min(sampleCount, 8))
        updated.timeoutSeconds = max(2, min(timeoutSeconds, 15))
        updated.notificationsEnabled = notificationsEnabled
        updated.notifyRecovery = notifyRecovery
        updated.notificationCooldownMinutes = max(1, notificationCooldownMinutes)
        return updated
    }
}

struct NetPulseConfigurationExport: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var exportedAt: Date
    var appName: String
    var targets: [ProbeTarget]
    var settings: SharedRuntimeSettings

    init(configuration: AppConfiguration, exportedAt: Date = Date()) {
        schemaVersion = Self.currentSchemaVersion
        self.exportedAt = exportedAt
        appName = "NetPulse"
        targets = configuration.targets
        settings = SharedRuntimeSettings(configuration: configuration)
    }

    static func load(from url: URL) throws -> NetPulseConfigurationExport {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let data = try Data(contentsOf: url)
        return try Self.decoder.decode(NetPulseConfigurationExport.self, from: data)
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

enum ConfigurationImportMode {
    case mergeTargets
    case replaceConfiguration

    var actionTitle: String {
        switch self {
        case .mergeTargets: "合并目标"
        case .replaceConfiguration: "替换配置"
        }
    }

    var confirmationMessage: String {
        switch self {
        case .mergeTargets:
            "只追加不存在的检测目标，当前运行设置不变。"
        case .replaceConfiguration:
            "会替换检测目标和可共享运行设置；登录启动等本机设置会保留。"
        }
    }
}

struct PendingConfigurationImport: Identifiable {
    let id = UUID()
    let export: NetPulseConfigurationExport
    let mode: ConfigurationImportMode
}

struct ConfigurationExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var export: NetPulseConfigurationExport

    init(export: NetPulseConfigurationExport) {
        self.export = export
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        export = try NetPulseConfigurationExport.decoder.decode(
            NetPulseConfigurationExport.self,
            from: data
        )
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try NetPulseConfigurationExport.encoder.encode(export)
        return FileWrapper(regularFileWithContents: data)
    }
}

extension AppConfiguration {
    func replacingSharedConfiguration(with export: NetPulseConfigurationExport) -> AppConfiguration {
        var updated = export.settings.applied(to: self)
        updated.targets = export.targets
        updated.launchAtLogin = launchAtLogin
        return updated.addingMissingBuiltInTargets()
    }

    func mergingTargets(from export: NetPulseConfigurationExport) -> AppConfiguration {
        var updated = self
        let existingIDs = Set(updated.targets.map(\.id))
        let existingURLs = Set(updated.targets.map(\.urlString))
        let existingNames = Set(updated.targets.map { "\($0.service)\u{1f}\($0.name)" })
        let missingTargets = export.targets.filter { target in
            !existingIDs.contains(target.id)
                && !existingURLs.contains(target.urlString)
                && !existingNames.contains("\(target.service)\u{1f}\(target.name)")
        }
        updated.targets.append(contentsOf: missingTargets)
        return updated.addingMissingBuiltInTargets()
    }
}
