import SwiftUI

struct ProbeResultRow: View {
    @EnvironmentObject private var model: AppModel
    let result: ProbeResult
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Button {
                    toggleExpanded()
                } label: {
                    HStack(spacing: 14) {
                        StatusDot(status: result.status)

                        Image(systemName: result.target.category.symbol)
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 7) {
                                Text(result.target.name)
                                    .font(.body.weight(.medium))
                                Text(result.target.service)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                PerformanceLabel(rating: result.performanceRating)
                            }
                            Text(rowSubtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .help(result.routeExplanation)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                MetricCell(
                    title: "成功",
                    value: "\(result.successCount)/\(result.samples.count)",
                    color: result.failureCount == 0 ? .green : .orange,
                    help: "成功完成真实 HTTP 访问的采样数 / 总采样数"
                )
                MetricCell(
                    title: "丢失",
                    value: "\(Int(result.lossPercent))%",
                    color: result.failureCount == 0 ? .primary : .red,
                    help: "失败或超时的采样比例"
                )
                MetricCell(
                    title: "中位",
                    value: formatMilliseconds(result.medianMs),
                    color: latencyColor(result.medianMs),
                    help: "成功采样总耗时的中位数，代表典型体验"
                )
                MetricCell(
                    title: "P95",
                    value: formatMilliseconds(result.p95Ms),
                    color: latencyColor(result.p95Ms),
                    help: "95% 采样不超过此耗时；当前仅采样 3 次时，它接近最慢一次"
                )
                MetricCell(
                    title: "最慢",
                    value: formatMilliseconds(result.worstMs),
                    color: latencyColor(result.worstMs),
                    help: "所有采样中耗时最长的一次，包含失败和超时"
                )

                Button {
                    model.setTarget(
                        result.target,
                        pinned: !model.isTargetPinned(result.target.id)
                    )
                } label: {
                    Image(
                        systemName: model.isTargetPinned(result.target.id)
                            ? "pin.fill"
                            : "pin"
                    )
                    .frame(width: 18)
                }
                .buttonStyle(.borderless)
                .help(model.isTargetPinned(result.target.id) ? "取消置顶" : "置顶目标")

                Button {
                    toggleExpanded()
                } label: {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 18)
                }
                .buttonStyle(.borderless)
                .help(expanded ? "收起详情" : "展开详情")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            if expanded {
                details
            }
        }
        .background(
            model.isTargetPinned(result.target.id)
                ? Color.accentColor.opacity(0.055)
                : Color.clear
        )
    }

    private var details: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Label(result.routeLabel, systemImage: "network")
                if !result.resolvedAddresses.isEmpty {
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(addressDetail)
                        .textSelection(.enabled)
                }
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .help(result.routeExplanation)

            ForEach(Array(result.samples.enumerated()), id: \.element.id) { index, sample in
                SampleRow(index: index + 1, sample: sample)
            }
            if let error = result.latestError {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .textSelection(.enabled)
                    Spacer()
                }
                .padding(.top, 4)
            }
            Text(result.target.urlString)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 58)
        .padding(.bottom, 14)
    }

    private var rowSubtitle: String {
        if result.usesFakeIPAddress {
            return URL(string: result.target.urlString)?.host ?? result.target.urlString
        }
        return result.routeLabel + routeAddressSuffix
    }

    private var routeAddressSuffix: String {
        guard !result.resolvedAddresses.isEmpty else { return "" }
        return " · " + result.resolvedAddresses.prefix(2).joined(separator: ", ")
    }

    private var addressDetail: String {
        let addresses = result.resolvedAddresses.prefix(2).joined(separator: ", ")
        return result.usesFakeIPAddress ? "虚拟映射 \(addresses)" : addresses
    }

    private func toggleExpanded() {
        withAnimation(.easeInOut(duration: 0.15)) {
            expanded.toggle()
        }
    }
}

struct SampleRow: View {
    let index: Int
    let sample: ProbeSample

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 0) {
            GridRow {
                Label("样本 \(index)", systemImage: sample.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(sample.ok ? .green : .red)
                    .frame(width: 95, alignment: .leading)
                SampleMetric(label: "DNS", value: sample.timings.dnsMs)
                SampleMetric(label: "TCP", value: sample.timings.tcpMs)
                SampleMetric(label: "TLS", value: sample.timings.tlsMs)
                SampleMetric(label: "首包", value: sample.timings.firstByteMs)
                SampleMetric(label: "总计", value: sample.timings.totalMs)
                Text(sample.statusCode.map { "HTTP \($0)" } ?? sample.errorPhase?.uppercased() ?? "—")
                    .font(.caption.monospacedDigit())
                    .frame(width: 80, alignment: .trailing)
            }
        }
        .font(.caption)
        .padding(.vertical, 4)
    }
}

struct SampleMetric: View {
    let label: String
    let value: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).foregroundStyle(.secondary)
            Text(formatMilliseconds(value))
                .monospacedDigit()
                .foregroundStyle(latencyColor(value))
        }
        .frame(width: 68, alignment: .leading)
    }
}

struct MetricCell: View {
    let title: String
    let value: String
    let color: Color
    let help: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.monospacedDigit())
                .foregroundStyle(color)
        }
        .frame(width: 58, alignment: .trailing)
        .help(help)
    }
}

struct PerformanceLabel: View {
    let rating: PerformanceRating

    var body: some View {
        Label(rating.title, systemImage: performanceSymbol(rating))
            .font(.caption2.weight(.medium))
            .foregroundStyle(performanceColor(rating))
            .accessibilityLabel("性能\(rating.title)")
    }
}
