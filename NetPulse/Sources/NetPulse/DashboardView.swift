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
