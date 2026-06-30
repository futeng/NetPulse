import Foundation

struct AddressProbeStatistics: Equatable {
    let address: String
    let sampleCount: Int
    let failureCount: Int
    let medianMs: Double?

    var failurePercent: Double {
        guard sampleCount > 0 else { return 0 }
        return Double(failureCount) / Double(sampleCount) * 100
    }
}

struct CDNRouteInsight: Equatable {
    let host: String
    let problematic: AddressProbeStatistics
    let healthy: AddressProbeStatistics
    let currentAddress: String

    var isCurrentPathProblematic: Bool {
        currentAddress == problematic.address
    }

    var title: String {
        isCurrentPathProblematic ? "当前 CDN 路径不稳定" : "检测到 CDN 调度波动"
    }

    var summary: String {
        if isCurrentPathProblematic {
            return "\(problematic.address) 的历史探测失败率为 \(formatted(problematic.failurePercent))，"
                + "而 \(healthy.address) 为 \(formatted(healthy.failurePercent))。"
                + "这通常是代理节点到 CDN 地址的互联问题，优先切换 Shadowrocket 节点后重新检测。"
        }

        return "\(host) 曾被调度到 \(problematic.address)，历史探测失败率为 "
            + "\(formatted(problematic.failurePercent))；当前 \(currentAddress) 表现正常。"
            + "如果问题再次出现，优先切换 Shadowrocket 节点。"
    }

    var temporaryHostRule: String {
        "\(host) = \(healthy.address)"
    }

    private func formatted(_ percent: Double) -> String {
        "\(Int(percent.rounded()))%"
    }
}

func cdnRouteInsight(
    for currentResult: ProbeResult,
    history: [NetworkRun],
    maximumRuns: Int = 30,
    minimumSamplesPerAddress: Int = 6
) -> CDNRouteInsight? {
    guard let host = URL(string: currentResult.target.urlString)?.host,
          currentResult.resolvedAddresses.count == 1,
          let currentAddress = currentResult.resolvedAddresses.first,
          !currentResult.usesFakeIPAddress else {
        return nil
    }

    var samplesByAddress: [String: [ProbeSample]] = [:]
    for run in history.prefix(maximumRuns) {
        guard let result = run.results.first(where: {
            matchesTarget($0.target, currentResult.target)
        }),
        result.resolvedAddresses.count == 1,
        let address = result.resolvedAddresses.first,
        !result.usesFakeIPAddress else {
            continue
        }
        samplesByAddress[address, default: []].append(contentsOf: result.samples)
    }

    let statistics = samplesByAddress.map { address, samples in
        AddressProbeStatistics(
            address: address,
            sampleCount: samples.count,
            failureCount: samples.filter { !$0.ok }.count,
            medianMs: percentile(samples.filter(\.ok).map(\.timings.totalMs), 0.5)
        )
    }
    .filter { $0.sampleCount >= minimumSamplesPerAddress }

    guard statistics.count >= 2,
          let problematic = statistics
            .filter({ $0.failurePercent >= 25 })
            .max(by: { $0.failurePercent < $1.failurePercent }),
          let healthy = statistics
            .filter({ $0.address != problematic.address && $0.failurePercent <= 10 })
            .sorted(by: preferredHealthyAddress)
            .first else {
        return nil
    }

    return CDNRouteInsight(
        host: host,
        problematic: problematic,
        healthy: healthy,
        currentAddress: currentAddress
    )
}

private func matchesTarget(_ left: ProbeTarget, _ right: ProbeTarget) -> Bool {
    left.id == right.id
        || (
            left.service == right.service
                && left.name == right.name
                && left.urlString == right.urlString
        )
}

private func preferredHealthyAddress(
    _ left: AddressProbeStatistics,
    _ right: AddressProbeStatistics
) -> Bool {
    if left.failurePercent != right.failurePercent {
        return left.failurePercent < right.failurePercent
    }
    return (left.medianMs ?? .infinity) < (right.medianMs ?? .infinity)
}
