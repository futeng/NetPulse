import Foundation

enum ProbeCategory: String, Codable, CaseIterable, Identifiable {
    case text = "文字"
    case image = "图片"
    case video = "视频"
    case api = "API"
    case custom = "自定义"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .text: "doc.text"
        case .image: "photo"
        case .video: "play.rectangle"
        case .api: "point.3.connected.trianglepath.dotted"
        case .custom: "globe"
        }
    }
}

enum HealthStatus: String, Codable {
    case idle
    case healthy
    case degraded
    case down

    var title: String {
        switch self {
        case .idle: "未检测"
        case .healthy: "正常"
        case .degraded: "不稳定"
        case .down: "不可用"
        }
    }
}

enum PerformanceRating: String, Codable {
    case idle
    case excellent
    case good
    case slow
    case verySlow
    case unstable
    case unavailable

    var title: String {
        switch self {
        case .idle: "未检测"
        case .excellent: "优秀"
        case .good: "良好"
        case .slow: "偏慢"
        case .verySlow: "很慢"
        case .unstable: "不稳定"
        case .unavailable: "不可用"
        }
    }
}

enum MenuBarNetworkPace {
    case idle
    case excellent
    case good
    case slow
    case verySlow
    case unstable
    case unavailable
    case checking
}

enum MenuBarRunner: String, CaseIterable, Identifiable {
    case sailfish
    case clownFish
    case arowana
    case bettaFish
    case goldfish
    case guppy
    case neonTetra
    case angelfish
    case pufferFish
    case signalShuttle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sailfish:
            return "旗鱼"
        case .clownFish:
            return "小丑鱼"
        case .arowana:
            return "龙鱼"
        case .bettaFish:
            return "斗鱼"
        case .goldfish:
            return "金鱼"
        case .guppy:
            return "孔雀鱼"
        case .neonTetra:
            return "霓虹灯鱼"
        case .angelfish:
            return "神仙鱼"
        case .pufferFish:
            return "河豚"
        case .signalShuttle:
            return "信号梭"
        }
    }
}

extension MenuBarRunner: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        if ["otter", "dolphin", "tropicalFish"].contains(rawValue) {
            self = .sailfish
        } else if let runner = MenuBarRunner(rawValue: rawValue) {
            self = runner
        } else {
            self = .sailfish
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct ProbeTarget: Identifiable, Codable, Hashable {
    var id: UUID
    var service: String
    var name: String
    var category: ProbeCategory
    var urlString: String
    var acceptedStatusCodes: [Int]
    var acceptAnyStatusBelow500: Bool
    var expectedContentPrefix: String?
    var minimumBytes: Int
    var rangeBytes: Int?
    var enabled: Bool
    var isBuiltIn: Bool
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        service: String,
        name: String,
        category: ProbeCategory,
        urlString: String,
        acceptedStatusCodes: [Int] = [],
        acceptAnyStatusBelow500: Bool = false,
        expectedContentPrefix: String? = nil,
        minimumBytes: Int = 0,
        rangeBytes: Int? = nil,
        enabled: Bool = true,
        isBuiltIn: Bool = false,
        isPinned: Bool = false
    ) {
        self.id = id
        self.service = service
        self.name = name
        self.category = category
        self.urlString = urlString
        self.acceptedStatusCodes = acceptedStatusCodes
        self.acceptAnyStatusBelow500 = acceptAnyStatusBelow500
        self.expectedContentPrefix = expectedContentPrefix
        self.minimumBytes = minimumBytes
        self.rangeBytes = rangeBytes
        self.enabled = enabled
        self.isBuiltIn = isBuiltIn
        self.isPinned = isPinned
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case service
        case name
        case category
        case urlString
        case acceptedStatusCodes
        case acceptAnyStatusBelow500
        case expectedContentPrefix
        case minimumBytes
        case rangeBytes
        case enabled
        case isBuiltIn
        case isPinned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        service = try container.decode(String.self, forKey: .service)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(ProbeCategory.self, forKey: .category)
        urlString = try container.decode(String.self, forKey: .urlString)
        acceptedStatusCodes = try container.decode([Int].self, forKey: .acceptedStatusCodes)
        acceptAnyStatusBelow500 = try container.decode(
            Bool.self,
            forKey: .acceptAnyStatusBelow500
        )
        expectedContentPrefix = try container.decodeIfPresent(
            String.self,
            forKey: .expectedContentPrefix
        )
        minimumBytes = try container.decode(Int.self, forKey: .minimumBytes)
        rangeBytes = try container.decodeIfPresent(Int.self, forKey: .rangeBytes)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        isBuiltIn = try container.decode(Bool.self, forKey: .isBuiltIn)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }

    func updatingEditableFields(
        service: String,
        name: String,
        category: ProbeCategory,
        urlString: String,
        enabled: Bool,
        isPinned: Bool
    ) -> ProbeTarget {
        var updated = self
        updated.service = service
        updated.name = name
        updated.category = category
        updated.urlString = urlString
        updated.enabled = enabled
        updated.isPinned = isPinned
        return updated
    }

    private static func builtInID(_ value: String) -> UUID {
        guard let uuid = UUID(uuidString: value) else {
            preconditionFailure("Invalid built-in target UUID: \(value)")
        }
        return uuid
    }

    private static let grokWebID = builtInID("4F6F9B31-BB1C-44CE-8E6E-7B1651C4BB71")

    func applyingBuiltInProbeMigrations() -> ProbeTarget {
        guard isBuiltIn,
              id == Self.grokWebID,
              urlString == "https://grok.com/" else {
            return self
        }

        var updated = self
        updated.acceptedStatusCodes = [200, 403]
        return updated
    }

    static let builtIns: [ProbeTarget] = [
        ProbeTarget(
            service: "Google",
            name: "Google 文字",
            category: .text,
            urlString: "https://www.google.com/generate_204",
            acceptedStatusCodes: [204],
            isBuiltIn: true
        ),
        ProbeTarget(
            service: "Google",
            name: "Google 图片 CDN",
            category: .image,
            urlString: "https://www.gstatic.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png",
            acceptedStatusCodes: [200],
            expectedContentPrefix: "image/",
            minimumBytes: 1_000,
            isBuiltIn: true
        ),
        ProbeTarget(
            service: "Google",
            name: "YouTube 视频 CDN",
            category: .video,
            urlString: "https://redirector.googlevideo.com/report_mapping?di=no",
            acceptedStatusCodes: [200],
            expectedContentPrefix: "text/plain",
            minimumBytes: 1,
            isBuiltIn: true
        ),
        ProbeTarget(
            service: "X",
            name: "X 文字",
            category: .text,
            urlString: "https://x.com/robots.txt",
            acceptAnyStatusBelow500: true,
            minimumBytes: 100,
            isBuiltIn: true
        ),
        ProbeTarget(
            service: "X",
            name: "X 静态图片",
            category: .image,
            urlString: "https://abs.twimg.com/favicons/twitter.3.ico",
            acceptedStatusCodes: [200],
            expectedContentPrefix: "image/",
            minimumBytes: 100,
            isBuiltIn: true
        ),
        ProbeTarget(
            service: "X",
            name: "X 用户图片",
            category: .image,
            urlString: "https://pbs.twimg.com/media/BG48ENgCEAAIDl9.jpg",
            acceptedStatusCodes: [200],
            expectedContentPrefix: "image/jpeg",
            minimumBytes: 1_024,
            isBuiltIn: true
        ),
        ProbeTarget(
            service: "X",
            name: "X 视频",
            category: .video,
            urlString: "https://video.twimg.com/ext_tw_video/1267146872759685122/pu/vid/1280x720/TxbefN8HewPbI4K8.mp4?tag=10",
            acceptedStatusCodes: [200, 206],
            expectedContentPrefix: "video/mp4",
            minimumBytes: 4_096,
            rangeBytes: 65_536,
            isBuiltIn: true
        ),
        ProbeTarget(
            service: "ChatGPT",
            name: "ChatGPT 文字服务",
            category: .text,
            urlString: "https://chatgpt.com/public-api/conversation_limit",
            acceptedStatusCodes: [200],
            expectedContentPrefix: "application/json",
            minimumBytes: 20,
            isBuiltIn: true
        ),
        ProbeTarget(
            id: grokWebID,
            service: "Grok",
            name: "Grok Web",
            category: .text,
            urlString: "https://grok.com/",
            acceptedStatusCodes: [200, 403],
            expectedContentPrefix: "text/html",
            minimumBytes: 1_024,
            isBuiltIn: true
        ),
        ProbeTarget(
            id: builtInID("69218403-D74A-4D0B-A96C-E2FC54CBA63C"),
            service: "Grok",
            name: "Grok Imagine 视频生成",
            category: .video,
            urlString: "https://api.x.ai/v1/videos/generations",
            acceptedStatusCodes: [405],
            isBuiltIn: true
        ),
        ProbeTarget(
            id: builtInID("0E58BEB3-8AF5-4AF8-98E1-F28B55A1F174"),
            service: "Grok",
            name: "Grok API",
            category: .api,
            urlString: "https://api.x.ai/v1/models",
            acceptedStatusCodes: [401],
            expectedContentPrefix: "application/json",
            minimumBytes: 20,
            isBuiltIn: true
        ),
        ProbeTarget(
            service: "OpenAI",
            name: "OpenAI API",
            category: .api,
            urlString: "https://api.openai.com/v1/models",
            acceptedStatusCodes: [401],
            minimumBytes: 20,
            isBuiltIn: true
        ),
        ProbeTarget(
            service: "OpenAI",
            name: "OpenAI 静态资源",
            category: .image,
            urlString: "https://cdn.oaistatic.com/",
            acceptAnyStatusBelow500: true,
            isBuiltIn: true
        ),
        ProbeTarget(
            service: "OpenAI",
            name: "OpenAI 视频 CDN",
            category: .video,
            urlString: "https://videos.openai.com/",
            acceptAnyStatusBelow500: true,
            isBuiltIn: true
        )
    ]
}

func resultsWithPinnedTargetsFirst(
    _ results: [ProbeResult],
    pinnedTargetIDs: Set<UUID>
) -> [ProbeResult] {
    results.enumerated()
        .sorted { left, right in
            let leftPinned = pinnedTargetIDs.contains(left.element.target.id)
            let rightPinned = pinnedTargetIDs.contains(right.element.target.id)
            if leftPinned != rightPinned {
                return leftPinned && !rightPinned
            }
            return left.offset < right.offset
        }
        .map(\.element)
}

struct ProbeTimings: Codable, Hashable {
    var dnsMs: Double?
    var tcpMs: Double?
    var tlsMs: Double?
    var firstByteMs: Double?
    var totalMs: Double
}

struct ProbeSample: Identifiable, Codable, Hashable {
    var id = UUID()
    var ok: Bool
    var checkedAt: Date
    var statusCode: Int?
    var contentType: String?
    var bytesRead: Int
    var timings: ProbeTimings
    var protocolName: String?
    var isProxyConnection: Bool?
    var errorPhase: String?
    var errorDetail: String?
}

struct ProbeResult: Identifiable, Codable, Hashable {
    var id: UUID { target.id }
    var target: ProbeTarget
    var resolvedAddresses: [String]
    var samples: [ProbeSample]

    var successCount: Int { samples.filter(\.ok).count }
    var failureCount: Int { samples.count - successCount }
    var failurePercent: Double {
        guard !samples.isEmpty else { return 0 }
        return Double(failureCount) / Double(samples.count) * 100
    }
    var performanceRating: PerformanceRating {
        if samples.isEmpty { return .idle }
        if successCount == 0 { return .unavailable }
        if failureCount > 0 { return .unstable }
        return latencyPerformanceRating(for: medianMs)
    }
    var status: HealthStatus {
        switch performanceRating {
        case .idle: .idle
        case .excellent, .good: .healthy
        case .slow, .verySlow, .unstable: .degraded
        case .unavailable: .down
        }
    }
    var medianMs: Double? { percentile(samples.filter(\.ok).map(\.timings.totalMs), 0.5) }
    var p95Ms: Double? { percentile(samples.filter(\.ok).map(\.timings.totalMs), 0.95) }
    var worstMs: Double? { samples.map(\.timings.totalMs).max() }
    var hasLatencyOutlier: Bool {
        guard failureCount == 0,
              let medianMs,
              let p95Ms else {
            return false
        }
        return medianMs < 800 && p95Ms >= 800
    }
    var latestError: String? {
        samples.first(where: { !$0.ok }).flatMap {
            [$0.errorPhase, $0.errorDetail].compactMap { $0 }.joined(separator: ": ")
        }
    }
    var requiresBrowserVerification: Bool {
        target.category == .text
            && !samples.isEmpty
            && samples.allSatisfy { $0.ok && $0.statusCode == 403 }
    }
    var usesFakeIPAddress: Bool {
        resolvedAddresses.contains(where: isFakeIPv4)
    }
    var routeLabel: String {
        if usesFakeIPAddress {
            return "Shadowrocket TUN（虚拟 IP）"
        }
        if resolvedAddresses.contains(where: isPrivateOrReservedIPv4) {
            return "虚拟/内网 DNS 地址"
        }
        if samples.contains(where: { $0.isProxyConnection == true }) {
            return "系统代理"
        }
        return "系统路由"
    }
    var routeExplanation: String {
        if usesFakeIPAddress {
            return "Shadowrocket 的 TUN 模式已接管此连接。198.18/15 是代理软件用于域名映射的保留虚拟地址，不是你的公网 IP，也不是目标服务器的真实 IP。它只能说明流量进入了 TUN，最终是直连还是代理仍由 Shadowrocket 规则决定。"
        }
        if resolvedAddresses.contains(where: isPrivateOrReservedIPv4) {
            return "DNS 返回了内网或保留地址，通常来自本地网络、VPN 或代理软件。该地址不是你的公网出口地址。"
        }
        if samples.contains(where: { $0.isProxyConnection == true }) {
            return "系统报告此请求使用了代理连接。"
        }
        return "请求使用 macOS 当前的系统路由。是否经过外部路由器或上游 VPN，需要结合出口 IP 或路由设备确认。"
    }
}

struct NetworkRun: Identifiable, Codable, Hashable {
    var id = UUID()
    var startedAt: Date
    var finishedAt: Date
    var results: [ProbeResult]

    var durationMs: Double { finishedAt.timeIntervalSince(startedAt) * 1_000 }
    var failedCount: Int { results.filter { $0.status != .healthy }.count }
    var healthyCount: Int { results.filter { $0.status == .healthy }.count }
    var availableCount: Int { results.filter { $0.status != .down }.count }
    var hasSampleFailures: Bool { results.contains { $0.failureCount > 0 } }
    var status: HealthStatus {
        if results.isEmpty { return .idle }
        if results.contains(where: { $0.status == .down }) { return .down }
        if results.contains(where: { $0.status == .degraded }) { return .degraded }
        return .healthy
    }

    func replacingResult(_ result: ProbeResult) -> NetworkRun {
        var updated = self
        if let index = updated.results.firstIndex(where: { $0.target.id == result.target.id }) {
            updated.results[index] = result
        } else {
            updated.results.append(result)
            updated.results.sort {
                if $0.target.service == $1.target.service {
                    return $0.target.name < $1.target.name
                }
                return $0.target.service < $1.target.service
            }
        }
        return updated
    }
}

func weightedNetworkScore(
    results: [ProbeResult],
    pinnedTargetIDs: Set<UUID>
) -> Double? {
    guard !results.isEmpty else { return nil }

    var weightedTotal = 0.0
    var totalWeight = 0.0

    for result in results {
        let weight = pinnedTargetIDs.contains(result.target.id) ? 2.6 : 1.0
        weightedTotal += networkScore(for: result) * weight
        totalWeight += weight
    }

    guard totalWeight > 0 else { return nil }
    return weightedTotal / totalWeight
}

func menuBarPace(
    forWeightedScore score: Double?,
    availableCount: Int,
    totalCount: Int
) -> MenuBarNetworkPace {
    guard let score, totalCount > 0 else { return .idle }
    if availableCount == 0 { return .unavailable }
    if score >= 90 { return .excellent }
    if score >= 72 { return .good }
    if score >= 52 { return .slow }
    if score >= 32 { return .verySlow }
    return .unstable
}

private func networkScore(for result: ProbeResult) -> Double {
    guard !result.samples.isEmpty else { return 55 }
    guard result.successCount > 0 else { return 0 }

    let reliability = Double(result.successCount) / Double(result.samples.count)
    let typicalScore = latencyScore(for: result.medianMs)
    let tailScore = latencyScore(for: result.p95Ms)
    let base = typicalScore * 0.8 + tailScore * 0.2
    let failurePenalty = Double(result.failureCount) / Double(result.samples.count) * 18
    return max(0, min(100, base * reliability - failurePenalty))
}

private func latencyScore(for milliseconds: Double?) -> Double {
    guard let milliseconds else { return 55 }
    if milliseconds < 300 { return 100 }
    if milliseconds < 800 { return 86 }
    if milliseconds < 1_500 { return 68 }
    if milliseconds < 3_000 { return 48 }
    return 35
}

struct AppConfiguration: Codable, Equatable {
    var targets: [ProbeTarget]
    var scheduleEnabled: Bool
    var intervalMinutes: Int
    var sampleCount: Int
    var timeoutSeconds: Double
    var notificationsEnabled: Bool
    var notifyRecovery: Bool
    var notificationCooldownMinutes: Int
    var launchAtLogin: Bool
    var exitIPCheckEnabled: Bool
    var ipinfoLiteToken: String
    var menuBarRunner: MenuBarRunner

    init(
        targets: [ProbeTarget],
        scheduleEnabled: Bool,
        intervalMinutes: Int,
        sampleCount: Int,
        timeoutSeconds: Double,
        notificationsEnabled: Bool,
        notifyRecovery: Bool,
        notificationCooldownMinutes: Int,
        launchAtLogin: Bool,
        exitIPCheckEnabled: Bool = false,
        ipinfoLiteToken: String = "",
        menuBarRunner: MenuBarRunner = .sailfish
    ) {
        self.targets = targets
        self.scheduleEnabled = scheduleEnabled
        self.intervalMinutes = intervalMinutes
        self.sampleCount = sampleCount
        self.timeoutSeconds = timeoutSeconds
        self.notificationsEnabled = notificationsEnabled
        self.notifyRecovery = notifyRecovery
        self.notificationCooldownMinutes = notificationCooldownMinutes
        self.launchAtLogin = launchAtLogin
        self.exitIPCheckEnabled = exitIPCheckEnabled
        self.ipinfoLiteToken = ipinfoLiteToken
        self.menuBarRunner = menuBarRunner
    }

    private enum CodingKeys: String, CodingKey {
        case targets
        case scheduleEnabled
        case intervalMinutes
        case sampleCount
        case timeoutSeconds
        case notificationsEnabled
        case notifyRecovery
        case notificationCooldownMinutes
        case launchAtLogin
        case exitIPCheckEnabled
        case ipinfoLiteToken
        case menuBarRunner
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        targets = try container.decode([ProbeTarget].self, forKey: .targets)
        scheduleEnabled = try container.decode(Bool.self, forKey: .scheduleEnabled)
        intervalMinutes = try container.decode(Int.self, forKey: .intervalMinutes)
        sampleCount = try container.decode(Int.self, forKey: .sampleCount)
        timeoutSeconds = try container.decode(Double.self, forKey: .timeoutSeconds)
        notificationsEnabled = try container.decode(Bool.self, forKey: .notificationsEnabled)
        notifyRecovery = try container.decode(Bool.self, forKey: .notifyRecovery)
        notificationCooldownMinutes = try container.decode(
            Int.self,
            forKey: .notificationCooldownMinutes
        )
        launchAtLogin = try container.decode(Bool.self, forKey: .launchAtLogin)
        exitIPCheckEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .exitIPCheckEnabled
        ) ?? false
        ipinfoLiteToken = try container.decodeIfPresent(
            String.self,
            forKey: .ipinfoLiteToken
        ) ?? ""
        menuBarRunner = try container.decodeIfPresent(
            MenuBarRunner.self,
            forKey: .menuBarRunner
        ) ?? .sailfish
    }

    static let `default` = AppConfiguration(
        targets: ProbeTarget.builtIns,
        scheduleEnabled: true,
        intervalMinutes: 5,
        sampleCount: 3,
        timeoutSeconds: 5,
        notificationsEnabled: true,
        notifyRecovery: true,
        notificationCooldownMinutes: 30,
        launchAtLogin: false,
        exitIPCheckEnabled: false,
        ipinfoLiteToken: "",
        menuBarRunner: .sailfish
    )

    func addingMissingBuiltInTargets() -> AppConfiguration {
        var updated = self
        updated.targets = updated.targets.map { $0.applyingBuiltInProbeMigrations() }
        let existingIDs = Set(updated.targets.map(\.id))
        let existingURLs = Set(updated.targets.map(\.urlString))
        let existingNames = Set(updated.targets.map { "\($0.service)\u{1f}\($0.name)" })
        let missingBuiltIns = ProbeTarget.builtIns.filter { target in
            !existingIDs.contains(target.id)
                && !existingURLs.contains(target.urlString)
                && !existingNames.contains("\(target.service)\u{1f}\(target.name)")
        }

        if !missingBuiltIns.isEmpty {
            updated.targets.append(contentsOf: missingBuiltIns)
        }
        return updated
    }
}

func percentile(_ values: [Double], _ fraction: Double) -> Double? {
    guard !values.isEmpty else { return nil }
    let sorted = values.sorted()
    let index = Int(ceil(Double(sorted.count) * fraction)) - 1
    return sorted[max(0, min(index, sorted.count - 1))]
}

func latencyPerformanceRating(for milliseconds: Double?) -> PerformanceRating {
    guard let milliseconds else { return .idle }
    if milliseconds < 300 { return .excellent }
    if milliseconds < 800 { return .good }
    if milliseconds < 1_500 { return .slow }
    return .verySlow
}

private func isFakeIPv4(_ address: String) -> Bool {
    let parts = address.split(separator: ".").compactMap { Int($0) }
    guard parts.count == 4 else { return false }
    return parts[0] == 198 && (parts[1] == 18 || parts[1] == 19)
}

private func isPrivateOrReservedIPv4(_ address: String) -> Bool {
    let parts = address.split(separator: ".").compactMap { Int($0) }
    guard parts.count == 4 else { return false }
    let first = parts[0]
    let second = parts[1]
    return first == 10
        || first == 127
        || (first == 169 && second == 254)
        || (first == 172 && (16...31).contains(second))
        || (first == 192 && second == 168)
        || (first == 100 && (64...127).contains(second))
}
