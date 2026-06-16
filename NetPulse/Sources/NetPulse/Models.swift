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
            id: builtInID("4F6F9B31-BB1C-44CE-8E6E-7B1651C4BB71"),
            service: "Grok",
            name: "Grok Web",
            category: .text,
            urlString: "https://grok.com/",
            acceptedStatusCodes: [200],
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
    var lossPercent: Double {
        guard !samples.isEmpty else { return 0 }
        return Double(failureCount) / Double(samples.count) * 100
    }
    var performanceRating: PerformanceRating {
        if samples.isEmpty { return .idle }
        if successCount == 0 { return .unavailable }
        if failureCount > 0 { return .unstable }
        return latencyPerformanceRating(for: p95Ms)
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
    var latestError: String? {
        samples.first(where: { !$0.ok }).flatMap {
            [$0.errorPhase, $0.errorDetail].compactMap { $0 }.joined(separator: ": ")
        }
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

    static let `default` = AppConfiguration(
        targets: ProbeTarget.builtIns,
        scheduleEnabled: true,
        intervalMinutes: 5,
        sampleCount: 3,
        timeoutSeconds: 5,
        notificationsEnabled: true,
        notifyRecovery: true,
        notificationCooldownMinutes: 30,
        launchAtLogin: false
    )

    func addingMissingBuiltInTargets() -> AppConfiguration {
        var updated = self
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
