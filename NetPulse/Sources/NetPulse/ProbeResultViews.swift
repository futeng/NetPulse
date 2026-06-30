import SwiftUI

struct ProbeResultRow: View {
    @EnvironmentObject private var model: AppModel
    let result: ProbeResult
    @State private var expanded = false

    private var routeInsight: CDNRouteInsight? {
        model.routeInsight(for: result)
    }

    private var isTargetRunning: Bool {
        model.isTargetRunning(result.target.id)
    }

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
                                if routeInsight?.isCurrentPathProblematic == true {
                                    Label("CDN 路径异常", systemImage: "point.3.connected.trianglepath.dotted")
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(.orange)
                                }
                                if result.requiresBrowserVerification {
                                    Label("需浏览器验证", systemImage: "checkmark.shield")
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(.secondary)
                                        .help("网络入口可达；Grok 的 Cloudflare 防护要求真实浏览器完成验证")
                                }
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
                    title: "失败",
                    value: "\(Int(result.failurePercent))%",
                    color: result.failureCount == 0 ? .primary : .red,
                    help: "HTTP 探测失败或超时的比例，不等同于底层网络丢包率"
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
        .contextMenu {
            Button {
                model.runTargetNow(result.target)
            } label: {
                Label("仅检测此目标", systemImage: "arrow.clockwise")
            }
            .disabled(model.isAnyProbeRunning)
        }
    }

    private var details: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Label(result.routeLabel, systemImage: "network")
                    .help(result.routeExplanation)
                if !result.resolvedAddresses.isEmpty {
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(addressDetail)
                        .textSelection(.enabled)
                        .help(result.routeExplanation)
                }
                Spacer()
                if let checkedAt = result.samples.last?.checkedAt {
                    Text("检测于 \(checkedAt.formatted(date: .omitted, time: .standard))")
                        .foregroundStyle(.tertiary)
                }
                Button {
                    model.runTargetNow(result.target)
                } label: {
                    if isTargetRunning {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("检测中")
                        }
                    } else {
                        Label("检测此目标", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(model.isAnyProbeRunning)
                .accessibilityLabel(isTargetRunning ? "正在检测此目标" : "检测此目标")
                .help("仅检测此目标，按当前设置采样 \(model.configuration.sampleCount) 次")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

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
            if let routeInsight {
                CDNRouteInsightCard(insight: routeInsight)
                    .environmentObject(model)
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

private struct CDNRouteInsightCard: View {
    @EnvironmentObject private var model: AppModel
    let insight: CDNRouteInsight

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.isCurrentPathProblematic
                ? "exclamationmark.arrow.triangle.2.circlepath"
                : "point.3.connected.trianglepath.dotted")
                .foregroundStyle(insight.isCurrentPathProblematic ? .orange : .secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 5) {
                Text(insight.title)
                    .font(.caption.weight(.semibold))
                Text(insight.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Menu {
                Button {
                    model.openShadowrocket()
                } label: {
                    Label("打开 Shadowrocket", systemImage: "app.dashed")
                }

                Button {
                    model.copyToPasteboard(insight.temporaryHostRule)
                } label: {
                    Label("复制临时 Host 映射", systemImage: "doc.on.doc")
                }

                Button {
                    model.copyToPasteboard(shadowrocketXRules)
                } label: {
                    Label("复制 X 代理规则", systemImage: "list.bullet.clipboard")
                }
            } label: {
                Label("处理建议", systemImage: "wrench.and.screwdriver")
                    .font(.caption)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("优先切换代理节点；Host 映射仅用于临时绕开异常 CDN 地址")
        }
        .padding(10)
        .background(Color.orange.opacity(insight.isCurrentPathProblematic ? 0.08 : 0.045))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.orange.opacity(0.18), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var shadowrocketXRules: String {
        """
        DOMAIN-SUFFIX,x.com,PROXY
        DOMAIN-SUFFIX,t.co,PROXY
        DOMAIN-SUFFIX,twimg.com,PROXY
        """
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
