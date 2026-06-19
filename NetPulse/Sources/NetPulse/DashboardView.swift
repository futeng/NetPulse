import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingHistory = false
    @State private var showingConfiguration = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            CurrentResultsView(
                showingHistory: $showingHistory,
                showingConfiguration: $showingConfiguration
            )
        }
        .frame(minWidth: 860, minHeight: 620)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showingHistory) {
            HistoryPanelView()
                .environmentObject(model)
        }
        .sheet(isPresented: $showingConfiguration) {
            ConfigurationPanelView()
                .environmentObject(model)
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            StatusMark(status: model.overallStatus, isRunning: model.isRunning)

            VStack(alignment: .leading, spacing: 3) {
                Text(model.isRunning ? "正在进行真实访问检测" : overallTitle)
                    .font(.title2.weight(.semibold))
                Text(summaryText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            ScheduleControl()

            Button {
                model.runNow()
            } label: {
                Label("立即检测", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isRunning)
            .keyboardShortcut("r", modifiers: [.command])
        }
        .padding(20)
    }

    private var overallTitle: String {
        switch model.overallStatus {
        case .idle: "尚未检测"
        case .healthy: "网络访问正常"
        case .degraded:
            if model.currentRun?.hasSampleFailures == true {
                "网络存在间歇性失败"
            } else {
                "网络可用，但部分响应偏慢"
            }
        case .down: "部分网络服务不可用"
        }
    }

    private var summaryText: String {
        guard let run = model.currentRun else {
            return "检测 DNS、TCP、TLS、HTTP 首包和真实内容读取"
        }
        return "健康 \(run.healthyCount)/\(run.results.count) · 可用 \(run.availableCount)/\(run.results.count) · 总耗时 \(formatMilliseconds(run.durationMs)) · \(run.finishedAt.formatted(date: .omitted, time: .standard))"
    }
}

private struct ScheduleControl: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingCustomInterval = false
    @State private var customInterval = 5

    private let commonIntervals = [1, 5, 15, 30]

    var body: some View {
        Menu {
            ForEach(commonIntervals, id: \.self) { minutes in
                Button {
                    model.setScheduleInterval(minutes)
                } label: {
                    if model.configuration.scheduleEnabled
                        && model.configuration.intervalMinutes == minutes {
                        Label("每 \(minutes) 分钟", systemImage: "checkmark")
                    } else {
                        Text("每 \(minutes) 分钟")
                    }
                }
            }

            Divider()

            Button {
                customInterval = max(1, model.configuration.intervalMinutes)
                showingCustomInterval = true
            } label: {
                Label("自定义…", systemImage: "slider.horizontal.3")
            }

            if model.configuration.scheduleEnabled {
                Divider()
                Button {
                    model.setScheduleEnabled(false)
                } label: {
                    Label("关闭定时检测", systemImage: "pause.circle")
                }
            }
        } label: {
            Label(scheduleTitle, systemImage: "clock.arrow.circlepath")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .popover(isPresented: $showingCustomInterval, arrowEdge: .bottom) {
            CustomIntervalView(minutes: $customInterval) {
                model.setScheduleInterval(customInterval)
                showingCustomInterval = false
            }
        }
        .help("设置自动检测间隔")
    }

    private var scheduleTitle: String {
        guard model.configuration.scheduleEnabled else { return "定时已关闭" }
        return "每 \(model.configuration.intervalMinutes) 分钟"
    }
}

private struct CustomIntervalView: View {
    @Binding var minutes: Int
    let apply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("自定义检测间隔")
                .font(.headline)

            Stepper(value: $minutes, in: 1...1_440) {
                Text("每 \(minutes) 分钟")
                    .monospacedDigit()
            }

            HStack {
                Spacer()
                Button("应用", action: apply)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 260)
    }
}

struct CurrentResultsView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var showingHistory: Bool
    @Binding var showingConfiguration: Bool
    @State private var showingMetricGuide = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if model.isRunning && model.currentRun == nil {
                Spacer()
                ProgressView("正在并发检测所有目标…")
                Spacer()
            } else if model.displayedResults.isEmpty {
                EmptyStateView(
                    title: "没有检测结果",
                    symbol: "network",
                    detail: "点击“立即检测”开始。"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if model.configuration.exitIPCheckEnabled
                            || !model.configuration.ipinfoLiteToken.isEmpty {
                            ExitIPSummaryCard(showingConfiguration: $showingConfiguration)
                            Divider()
                                .padding(.leading, 20)
                        }

                        ForEach(model.displayedResults) { result in
                            ProbeResultRow(result: result)
                            Divider()
                                .padding(.leading, 20)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingMetricGuide) {
            MetricGuideView()
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Picker("服务", selection: $model.selectedService) {
                ForEach(model.services, id: \.self) { service in
                    Text(service).tag(service)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            if model.displayedResults.contains(where: \.usesFakeIPAddress) {
                Label("TUN 已接管", systemImage: "network")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help("Shadowrocket TUN 正在接管这些连接。具体虚拟 IP 可展开单项查看。")
            }

            if let run = model.currentRun {
                Text("每项 \(model.configuration.sampleCount) 次采样")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.tertiary)
                Text("超时 \(Int(model.configuration.timeoutSeconds)) 秒")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(run.startedAt.formatted(date: .abbreviated, time: .standard))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                showingMetricGuide = true
            } label: {
                Image(systemName: "info.circle")
            }
            .buttonStyle(.borderless)
            .help("指标说明")

            Button {
                showingHistory = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
            }
            .buttonStyle(.borderless)
            .help("检测历史")

            Button {
                showingConfiguration = true
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(.borderless)
            .help("检测目标与运行设置")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

private struct ExitIPSummaryCard: View {
    @EnvironmentObject private var model: AppModel
    @Binding var showingConfiguration: Bool

    var body: some View {
        HStack(spacing: 12) {
            statusIcon

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("出口 IP")
                        .font(.body.weight(.semibold))
                    Text("IPinfo Lite")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if let info = currentInfo {
                VStack(alignment: .trailing, spacing: 3) {
                    Text(info.ip)
                        .font(.callout.monospacedDigit().weight(.medium))
                    Text(metaText(info))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Button {
                model.refreshExitIP()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(isChecking || !model.configuration.exitIPCheckEnabled)
            .help("刷新出口 IP")

            Button {
                showingConfiguration = true
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(.borderless)
            .help("配置出口 IP")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(cardBackground)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch model.exitIPState {
        case .checking:
            ProgressView()
                .scaleEffect(0.7)
                .frame(width: 18, height: 18)
        case .success:
            Image(systemName: "location.circle.fill")
                .foregroundStyle(.green)
                .frame(width: 18)
        case .failure:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .frame(width: 18)
        case .idle:
            Image(systemName: "location.circle")
                .foregroundStyle(.secondary)
                .frame(width: 18)
        }
    }

    private var detailText: String {
        switch model.exitIPState {
        case .idle:
            return "未启用出口 IP 检测"
        case .checking:
            return "正在通过当前系统路由请求 IPinfo Lite"
        case .success(let info):
            let time = info.checkedAt.formatted(date: .omitted, time: .standard)
            return "当前系统出口 · \(formatMilliseconds(info.durationMs)) · \(time)"
        case .failure(let message):
            return message
        }
    }

    private var currentInfo: ExitIPInfo? {
        if case .success(let info) = model.exitIPState {
            return info
        }
        return nil
    }

    private var isChecking: Bool {
        if case .checking = model.exitIPState { return true }
        return false
    }

    private var cardBackground: Color {
        switch model.exitIPState {
        case .failure:
            Color.orange.opacity(0.06)
        default:
            Color(nsColor: .controlBackgroundColor).opacity(0.35)
        }
    }

    private func metaText(_ info: ExitIPInfo) -> String {
        let location = info.locationText
        let organization = info.organizationText
        if !location.isEmpty && !organization.isEmpty {
            return "\(location) · \(organization)"
        }
        if !location.isEmpty { return location }
        if !organization.isEmpty { return organization }
        return "出口信息"
    }
}
