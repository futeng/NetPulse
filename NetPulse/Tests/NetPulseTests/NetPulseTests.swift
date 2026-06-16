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
        XCTAssertEqual(result.lossPercent, 100.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(result.medianMs, 75)
        XCTAssertEqual(result.worstMs, 5_000)
        XCTAssertEqual(result.performanceRating, .unstable)
        XCTAssertEqual(result.routeLabel, "Shadowrocket TUN（虚拟 IP）")
        XCTAssertTrue(result.usesFakeIPAddress)
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
}
