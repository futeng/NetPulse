import AppKit
import XCTest
@testable import NetPulse

final class NetPulseTests: XCTestCase {
    func testLegacyTargetWithoutPinnedFieldStillDecodes() throws {
        let json = """
        {
          "id": "4C6AFA8F-A212-4F8F-B490-AC3D23D10A61",
          "service": "Test",
          "name": "Legacy target",
          "category": "API",
          "urlString": "https://example.com",
          "acceptedStatusCodes": [200],
          "acceptAnyStatusBelow500": false,
          "minimumBytes": 0,
          "enabled": true,
          "isBuiltIn": false
        }
        """

        let target = try JSONDecoder().decode(
            ProbeTarget.self,
            from: Data(json.utf8)
        )

        XCTAssertFalse(target.isPinned)
    }

    func testLegacyConfigurationWithoutExitIPFieldsStillDecodes() throws {
        let json = """
        {
          "targets": [],
          "scheduleEnabled": true,
          "intervalMinutes": 5,
          "sampleCount": 3,
          "timeoutSeconds": 5,
          "notificationsEnabled": true,
          "notifyRecovery": true,
          "notificationCooldownMinutes": 30,
          "launchAtLogin": false
        }
        """

        let configuration = try JSONDecoder().decode(
            AppConfiguration.self,
            from: Data(json.utf8)
        )

        XCTAssertFalse(configuration.exitIPCheckEnabled)
        XCTAssertEqual(configuration.ipinfoLiteToken, "")
        XCTAssertEqual(configuration.menuBarRunner, .tropicalFish)
    }

    func testLegacyMenuBarRunnerMigratesToTropicalFish() throws {
        for legacyValue in ["otter", "dolphin"] {
            let json = "\"\(legacyValue)\""

            let runner = try JSONDecoder().decode(
                MenuBarRunner.self,
                from: Data(json.utf8)
            )

            XCTAssertEqual(runner, .tropicalFish)
        }
    }

    func testMenuBarRunnersRenderVisibleAnimatedFrames() throws {
        let first = MenuBarIconRenderer.image(for: .good, runner: .tropicalFish, phase: 0.1)
        let second = MenuBarIconRenderer.image(for: .good, runner: .tropicalFish, phase: 0.6)
        let firstPixels = try rgbaPixels(from: first)
        let secondPixels = try rgbaPixels(from: second)

        XCTAssertGreaterThan(nonTransparentPixelCount(firstPixels), 60)
        XCTAssertGreaterThan(nonTransparentPixelCount(secondPixels), 60)
        XCTAssertNotEqual(firstPixels, secondPixels)

        for runner in MenuBarRunner.allCases {
            let image = MenuBarIconRenderer.image(for: .slow, runner: runner, phase: 0.35)
            XCTAssertGreaterThan(nonTransparentPixelCount(try rgbaPixels(from: image)), 40)
        }

        let tropical = try rgbaPixels(
            from: MenuBarIconRenderer.image(for: .good, runner: .tropicalFish, phase: 0.35)
        )
        let clown = try rgbaPixels(
            from: MenuBarIconRenderer.image(for: .good, runner: .clownFish, phase: 0.35)
        )
        XCTAssertNotEqual(tropical, clown)
    }

    func testPinnedTargetsHaveHigherWeightInMenuBarScore() {
        let fast = ProbeResult(
            target: ProbeTarget(
                service: "Core",
                name: "Fast",
                category: .text,
                urlString: "https://fast.example.com"
            ),
            resolvedAddresses: [],
            samples: [successfulSample(totalMs: 120), successfulSample(totalMs: 130), successfulSample(totalMs: 140)]
        )
        let slow = ProbeResult(
            target: ProbeTarget(
                service: "Important",
                name: "Pinned slow",
                category: .api,
                urlString: "https://slow.example.com"
            ),
            resolvedAddresses: [],
            samples: [successfulSample(totalMs: 2_200), successfulSample(totalMs: 2_300), successfulSample(totalMs: 2_400)]
        )

        let unpinnedScore = weightedNetworkScore(results: [fast, slow], pinnedTargetIDs: []) ?? 0
        let pinnedScore = weightedNetworkScore(results: [fast, slow], pinnedTargetIDs: [slow.target.id]) ?? 0

        XCTAssertLessThan(pinnedScore, unpinnedScore)
        XCTAssertEqual(
            menuBarPace(forWeightedScore: 100, availableCount: 2, totalCount: 2),
            .excellent
        )
        XCTAssertEqual(
            menuBarPace(forWeightedScore: pinnedScore, availableCount: 2, totalCount: 2),
            .slow
        )
    }

    func testPinnedResultsAreMovedFirstWithoutReorderingOthers() {
        let first = makeEmptyResult(name: "First")
        let pinned = makeEmptyResult(name: "Pinned")
        let third = makeEmptyResult(name: "Third")

        let sorted = resultsWithPinnedTargetsFirst(
            [first, pinned, third],
            pinnedTargetIDs: [pinned.target.id]
        )

        XCTAssertEqual(sorted.map(\.target.name), ["Pinned", "First", "Third"])
    }

    func testBuiltInsIncludeGrokTargets() {
        let grokTargets = ProbeTarget.builtIns.filter { $0.service == "Grok" }

        XCTAssertEqual(grokTargets.map(\.name), [
            "Grok Web",
            "Grok Imagine 视频生成",
            "Grok API"
        ])
        XCTAssertEqual(grokTargets.map(\.urlString), [
            "https://grok.com/",
            "https://api.x.ai/v1/videos/generations",
            "https://api.x.ai/v1/models"
        ])
        XCTAssertEqual(grokTargets.map(\.isBuiltIn), [true, true, true])
        XCTAssertEqual(grokTargets.first?.acceptedStatusCodes, [200, 403])
    }

    func testExistingGrokWebTargetMigratesCloudflareChallengeStatus() {
        var configuration = AppConfiguration.default
        guard let index = configuration.targets.firstIndex(where: {
            $0.name == "Grok Web"
        }) else {
            return XCTFail("Missing Grok Web built-in")
        }
        configuration.targets[index].acceptedStatusCodes = [200]

        let migrated = configuration.addingMissingBuiltInTargets()
        let grokWeb = migrated.targets.first { $0.name == "Grok Web" }

        XCTAssertEqual(grokWeb?.acceptedStatusCodes, [200, 403])
    }

    func testAcceptedWebChallengeRequiresBrowserVerification() {
        let target = ProbeTarget(
            service: "Grok",
            name: "Grok Web",
            category: .text,
            urlString: "https://grok.com/",
            acceptedStatusCodes: [200, 403]
        )
        let challenge = ProbeSample(
            ok: true,
            checkedAt: Date(),
            statusCode: 403,
            contentType: "text/html",
            bytesRead: 5_000,
            timings: ProbeTimings(totalMs: 320),
            protocolName: "h2",
            isProxyConnection: false,
            errorPhase: nil,
            errorDetail: nil
        )
        let result = ProbeResult(
            target: target,
            resolvedAddresses: ["198.18.0.36"],
            samples: [challenge, challenge, challenge]
        )

        XCTAssertTrue(result.requiresBrowserVerification)
        XCTAssertEqual(result.status, .healthy)
    }

    func testMissingBuiltInsAreAddedWithoutDuplicatingExistingTargets() {
        let custom = ProbeTarget(
            service: "Custom",
            name: "Example",
            category: .custom,
            urlString: "https://example.com",
            acceptAnyStatusBelow500: true
        )
        let configuration = AppConfiguration.default
        var olderConfiguration = configuration
        olderConfiguration.targets = ProbeTarget.builtIns.filter { $0.service != "Grok" } + [custom]

        let migrated = olderConfiguration.addingMissingBuiltInTargets()
        let migratedAgain = migrated.addingMissingBuiltInTargets()

        XCTAssertEqual(migrated.targets.filter { $0.service == "Grok" }.count, 3)
        XCTAssertEqual(migratedAgain.targets.filter { $0.service == "Grok" }.count, 3)
        XCTAssertTrue(migrated.targets.contains(custom))
    }

    func testConfigurationExportRoundTrip() throws {
        var configuration = AppConfiguration.default
        configuration.exitIPCheckEnabled = true
        configuration.ipinfoLiteToken = "secret-token"
        let export = NetPulseConfigurationExport(
            configuration: configuration,
            exportedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        let data = try NetPulseConfigurationExport.encoder.encode(export)
        let decoded = try NetPulseConfigurationExport.decoder.decode(
            NetPulseConfigurationExport.self,
            from: data
        )

        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.appName, "NetPulse")
        XCTAssertEqual(decoded.targets.count, AppConfiguration.default.targets.count)
        XCTAssertEqual(decoded.settings.sampleCount, AppConfiguration.default.sampleCount)
        XCTAssertFalse(String(data: data, encoding: .utf8)?.contains("secret-token") ?? true)
    }

    func testReplacingSharedConfigurationPreservesLocalLaunchSetting() {
        var local = AppConfiguration.default
        local.launchAtLogin = true
        local.intervalMinutes = 30
        local.exitIPCheckEnabled = true
        local.ipinfoLiteToken = "local-token"

        var shared = AppConfiguration.default
        shared.launchAtLogin = false
        shared.intervalMinutes = 5
        shared.exitIPCheckEnabled = false
        shared.ipinfoLiteToken = "shared-token"
        shared.targets = ProbeTarget.builtIns.filter { $0.service == "Grok" }
        let export = NetPulseConfigurationExport(configuration: shared)

        let replaced = local.replacingSharedConfiguration(with: export)

        XCTAssertTrue(replaced.launchAtLogin)
        XCTAssertEqual(replaced.intervalMinutes, 5)
        XCTAssertTrue(replaced.exitIPCheckEnabled)
        XCTAssertEqual(replaced.ipinfoLiteToken, "local-token")
        XCTAssertEqual(replaced.targets.filter { $0.service == "Grok" }.count, 3)
    }

    func testMergingConfigurationAddsOnlyMissingTargets() {
        let existing = ProbeTarget(
            service: "Shared",
            name: "Existing",
            category: .api,
            urlString: "https://example.com/existing",
            acceptAnyStatusBelow500: true
        )
        let incoming = ProbeTarget(
            service: "Shared",
            name: "Incoming",
            category: .api,
            urlString: "https://example.com/incoming",
            acceptAnyStatusBelow500: true
        )
        var local = AppConfiguration.default
        local.targets.append(existing)
        var shared = AppConfiguration.default
        shared.targets = [existing, incoming]

        let merged = local.mergingTargets(from: NetPulseConfigurationExport(configuration: shared))

        XCTAssertEqual(merged.targets.filter { $0.urlString == existing.urlString }.count, 1)
        XCTAssertEqual(merged.targets.filter { $0.urlString == incoming.urlString }.count, 1)
    }

    func testEditingTargetPreservesDetectionRules() {
        let original = ProbeTarget(
            service: "X",
            name: "X 视频",
            category: .video,
            urlString: "https://video.twimg.com/original.mp4",
            acceptedStatusCodes: [200, 206],
            expectedContentPrefix: "video/mp4",
            minimumBytes: 4_096,
            rangeBytes: 65_536,
            isBuiltIn: true
        )

        let edited = original.updatingEditableFields(
            service: "媒体",
            name: "重点视频",
            category: .video,
            urlString: "https://video.twimg.com/updated.mp4",
            enabled: false,
            isPinned: true
        )

        XCTAssertEqual(edited.id, original.id)
        XCTAssertEqual(edited.service, "媒体")
        XCTAssertEqual(edited.name, "重点视频")
        XCTAssertEqual(edited.urlString, "https://video.twimg.com/updated.mp4")
        XCTAssertFalse(edited.enabled)
        XCTAssertTrue(edited.isPinned)
        XCTAssertTrue(edited.isBuiltIn)
        XCTAssertEqual(edited.acceptedStatusCodes, [200, 206])
        XCTAssertEqual(edited.expectedContentPrefix, "video/mp4")
        XCTAssertEqual(edited.minimumBytes, 4_096)
        XCTAssertEqual(edited.rangeBytes, 65_536)
    }

    private func rgbaPixels(from image: NSImage) throws -> [UInt8] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "NetPulseTests", code: 1)
        }

        var pixels = [UInt8](repeating: 0, count: cgImage.width * cgImage.height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: cgImage.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw NSError(domain: "NetPulseTests", code: 2)
        }

        context.draw(
            cgImage,
            in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        )
        return pixels
    }

    private func nonTransparentPixelCount(_ pixels: [UInt8]) -> Int {
        stride(from: 3, to: pixels.count, by: 4).reduce(0) { count, index in
            count + (pixels[index] > 0 ? 1 : 0)
        }
    }

    func testPercentile() {
        XCTAssertEqual(percentile([100, 200, 300], 0.5), 200)
        XCTAssertEqual(percentile([100, 200, 300], 0.95), 300)
        XCTAssertNil(percentile([], 0.5))
    }

    func testAggregateStatusExposesIntermittentFailure() {
        let target = ProbeTarget(
            service: "Test",
            name: "Intermittent",
            category: .api,
            urlString: "https://example.com",
            acceptAnyStatusBelow500: true
        )
        let success = ProbeSample(
            ok: true,
            checkedAt: Date(),
            statusCode: 200,
            contentType: "text/plain",
            bytesRead: 1,
            timings: ProbeTimings(totalMs: 75),
            protocolName: "h2",
            isProxyConnection: false,
            errorPhase: nil,
            errorDetail: nil
        )
        let timeout = ProbeSample(
            ok: false,
            checkedAt: Date(),
            statusCode: nil,
            contentType: nil,
            bytesRead: 0,
            timings: ProbeTimings(totalMs: 5_000),
            protocolName: nil,
            isProxyConnection: nil,
            errorPhase: "timeout",
            errorDetail: "timed out"
        )

        let result = ProbeResult(
            target: target,
            resolvedAddresses: ["198.18.0.1"],
            samples: [success, success, timeout]
        )

        XCTAssertEqual(result.status, .degraded)
        XCTAssertEqual(result.failurePercent, 100.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(result.medianMs, 75)
        XCTAssertEqual(result.worstMs, 5_000)
        XCTAssertEqual(result.performanceRating, .unstable)
        XCTAssertEqual(result.routeLabel, "Shadowrocket TUN（虚拟 IP）")
        XCTAssertTrue(result.usesFakeIPAddress)
    }

    func testCDNRouteInsightFindsProblematicAddress() {
        let target = ProbeTarget(
            service: "X",
            name: "X 视频",
            category: .video,
            urlString: "https://video.twimg.com/test.mp4"
        )
        let bad = makeResult(
            target: target,
            address: "140.248.128.158",
            samples: [
                failedSample(), failedSample(), successfulSample(totalMs: 1_400),
                failedSample(), failedSample(), successfulSample(totalMs: 1_300)
            ]
        )
        let good = makeResult(
            target: target,
            address: "146.75.44.158",
            samples: (0..<6).map { _ in successfulSample(totalMs: 220) }
        )
        let history = [
            makeRun(result: bad),
            makeRun(result: good)
        ]

        let insight = cdnRouteInsight(for: bad, history: history)

        XCTAssertEqual(insight?.problematic.address, "140.248.128.158")
        XCTAssertEqual(insight?.healthy.address, "146.75.44.158")
        XCTAssertEqual(
            insight?.problematic.failurePercent ?? -1,
            200.0 / 3.0,
            accuracy: 0.001
        )
        XCTAssertTrue(insight?.isCurrentPathProblematic == true)
        XCTAssertEqual(
            insight?.temporaryHostRule,
            "video.twimg.com = 146.75.44.158"
        )
    }

    func testCDNRouteInsightRemainsVisibleOnHealthyAddress() {
        let target = ProbeTarget(
            service: "X",
            name: "X 视频",
            category: .video,
            urlString: "https://video.twimg.com/test.mp4"
        )
        let bad = makeResult(
            target: target,
            address: "140.248.128.158",
            samples: (0..<6).map { _ in failedSample() }
        )
        let good = makeResult(
            target: target,
            address: "146.75.44.158",
            samples: (0..<6).map { _ in successfulSample(totalMs: 220) }
        )

        let insight = cdnRouteInsight(
            for: good,
            history: [makeRun(result: good), makeRun(result: bad)]
        )

        XCTAssertNotNil(insight)
        XCTAssertFalse(insight?.isCurrentPathProblematic == true)
    }

    func testCDNRouteInsightRequiresEnoughEvidence() {
        let target = ProbeTarget(
            service: "X",
            name: "X 视频",
            category: .video,
            urlString: "https://video.twimg.com/test.mp4"
        )
        let bad = makeResult(
            target: target,
            address: "140.248.128.158",
            samples: [failedSample(), failedSample(), successfulSample(totalMs: 1_300)]
        )
        let good = makeResult(
            target: target,
            address: "146.75.44.158",
            samples: (0..<6).map { _ in successfulSample(totalMs: 220) }
        )

        XCTAssertNil(
            cdnRouteInsight(
                for: bad,
                history: [makeRun(result: bad), makeRun(result: good)]
            )
        )
    }

    func testPrivateDNSAddressIsExposed() {
        let target = ProbeTarget(
            service: "Test",
            name: "Private DNS",
            category: .custom,
            urlString: "https://example.com",
            acceptAnyStatusBelow500: true
        )
        let result = ProbeResult(
            target: target,
            resolvedAddresses: ["192.168.1.100"],
            samples: []
        )
        XCTAssertEqual(result.routeLabel, "虚拟/内网 DNS 地址")
    }

    func testPerformanceThresholds() {
        XCTAssertEqual(latencyPerformanceRating(for: 299), .excellent)
        XCTAssertEqual(latencyPerformanceRating(for: 300), .good)
        XCTAssertEqual(latencyPerformanceRating(for: 799), .good)
        XCTAssertEqual(latencyPerformanceRating(for: 800), .slow)
        XCTAssertEqual(latencyPerformanceRating(for: 1_499), .slow)
        XCTAssertEqual(latencyPerformanceRating(for: 1_500), .verySlow)
    }

    func testSlowSuccessfulRequestIsNotReportedHealthy() {
        let target = ProbeTarget(
            service: "Test",
            name: "Slow API",
            category: .api,
            urlString: "https://example.com",
            acceptAnyStatusBelow500: true
        )
        let slow = ProbeSample(
            ok: true,
            checkedAt: Date(),
            statusCode: 200,
            contentType: "application/json",
            bytesRead: 100,
            timings: ProbeTimings(totalMs: 1_050),
            protocolName: "h2",
            isProxyConnection: true,
            errorPhase: nil,
            errorDetail: nil
        )
        let result = ProbeResult(
            target: target,
            resolvedAddresses: ["198.19.0.10"],
            samples: [slow, slow, slow]
        )

        XCTAssertEqual(result.performanceRating, .slow)
        XCTAssertEqual(result.status, .degraded)
        XCTAssertTrue(result.usesFakeIPAddress)
    }

    func testSingleLatencyOutlierDoesNotDegradeTypicalStatus() {
        let target = ProbeTarget(
            service: "Test",
            name: "Occasional spike",
            category: .api,
            urlString: "https://example.com",
            acceptAnyStatusBelow500: true
        )
        let result = ProbeResult(
            target: target,
            resolvedAddresses: [],
            samples: [
                successfulSample(totalMs: 420),
                successfulSample(totalMs: 460),
                successfulSample(totalMs: 1_900)
            ]
        )

        XCTAssertEqual(result.medianMs, 460)
        XCTAssertEqual(result.p95Ms, 1_900)
        XCTAssertEqual(result.performanceRating, .good)
        XCTAssertEqual(result.status, .healthy)
        XCTAssertTrue(result.hasLatencyOutlier)
    }

    func testReplacingSingleTargetResultPreservesRunAndOtherTargets() {
        let first = makeEmptyResult(name: "First")
        let second = makeEmptyResult(name: "Second")
        let run = NetworkRun(
            startedAt: Date(timeIntervalSince1970: 100),
            finishedAt: Date(timeIntervalSince1970: 110),
            results: [first, second]
        )
        let replacement = ProbeResult(
            target: first.target,
            resolvedAddresses: ["203.0.113.10"],
            samples: [successfulSample(totalMs: 125)]
        )

        let updated = run.replacingResult(replacement)

        XCTAssertEqual(updated.id, run.id)
        XCTAssertEqual(updated.startedAt, run.startedAt)
        XCTAssertEqual(updated.finishedAt, run.finishedAt)
        XCTAssertEqual(updated.results.count, 2)
        XCTAssertEqual(updated.results[0], replacement)
        XCTAssertEqual(updated.results[1], second)
    }

    private func makeEmptyResult(name: String) -> ProbeResult {
        ProbeResult(
            target: ProbeTarget(
                service: "Test",
                name: name,
                category: .custom,
                urlString: "https://example.com/\(name)"
            ),
            resolvedAddresses: [],
            samples: []
        )
    }

    private func makeResult(
        target: ProbeTarget,
        address: String,
        samples: [ProbeSample]
    ) -> ProbeResult {
        ProbeResult(
            target: target,
            resolvedAddresses: [address],
            samples: samples
        )
    }

    private func makeRun(result: ProbeResult) -> NetworkRun {
        NetworkRun(
            startedAt: Date(),
            finishedAt: Date(),
            results: [result]
        )
    }

    private func successfulSample(totalMs: Double) -> ProbeSample {
        ProbeSample(
            ok: true,
            checkedAt: Date(),
            statusCode: 200,
            contentType: "text/plain",
            bytesRead: 100,
            timings: ProbeTimings(totalMs: totalMs),
            protocolName: "h2",
            isProxyConnection: false,
            errorPhase: nil,
            errorDetail: nil
        )
    }

    private func failedSample() -> ProbeSample {
        ProbeSample(
            ok: false,
            checkedAt: Date(),
            statusCode: nil,
            contentType: nil,
            bytesRead: 0,
            timings: ProbeTimings(totalMs: 350),
            protocolName: nil,
            isProxyConnection: false,
            errorPhase: "tls",
            errorDetail: "connection reset"
        )
    }
}
