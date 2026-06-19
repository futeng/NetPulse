import SwiftUI

private enum ConfigurationSection: String, CaseIterable, Identifiable {
    case targets = "检测目标"
    case runtime = "运行设置"

    var id: String { rawValue }
}

struct ConfigurationPanelView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSection = ConfigurationSection.targets
    @State private var showingAddTarget = false
    @State private var showingRestoreConfirmation = false
    @State private var exportingConfiguration = false
    @State private var importingConfiguration = false
    @State private var importMode = ConfigurationImportMode.mergeTargets
    @State private var pendingImport: PendingConfigurationImport?
    @State private var importError: String?

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: "配置", symbol: "slider.horizontal.3") {
                dismiss()
            }

            HStack {
                Picker("配置区域", selection: $selectedSection) {
                    ForEach(ConfigurationSection.allCases) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 260)

                Spacer()

                if selectedSection == .targets {
                    Menu {
                        Button {
                            exportingConfiguration = true
                        } label: {
                            Label("导出配置", systemImage: "square.and.arrow.up")
                        }

                        Divider()

                        Button {
                            importMode = .mergeTargets
                            importingConfiguration = true
                        } label: {
                            Label("导入并合并目标", systemImage: "square.and.arrow.down")
                        }

                        Button {
                            importMode = .replaceConfiguration
                            importingConfiguration = true
                        } label: {
                            Label("导入并替换配置", systemImage: "arrow.triangle.2.circlepath")
                        }

                        Divider()

                        Button {
                            showingRestoreConfirmation = true
                        } label: {
                            Label("恢复所有内置目标", systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("更多目标操作")

                    Button {
                        showingAddTarget = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("添加检测目标")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            switch selectedSection {
            case .targets:
                TargetManagerView()
            case .runtime:
                RuntimeSettingsView()
            }
        }
        .frame(width: 720, height: 600)
        .sheet(isPresented: $showingAddTarget) {
            TargetEditorView()
        }
        .fileExporter(
            isPresented: $exportingConfiguration,
            document: ConfigurationExportDocument(
                export: NetPulseConfigurationExport(configuration: model.configuration)
            ),
            contentType: .json,
            defaultFilename: "NetPulse-Config"
        ) { result in
            if case .failure(let error) = result {
                importError = "导出失败：\(error.localizedDescription)"
            }
        }
        .fileImporter(
            isPresented: $importingConfiguration,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .confirmationDialog(
            "导入 NetPulse 配置？",
            isPresented: Binding(
                get: { pendingImport != nil },
                set: { if !$0 { pendingImport = nil } }
            )
        ) {
            if let pendingImport {
                Button(pendingImport.mode.actionTitle) {
                    model.importConfiguration(
                        pendingImport.export,
                        mode: pendingImport.mode
                    )
                    self.pendingImport = nil
                }
            }
            Button("取消", role: .cancel) {
                pendingImport = nil
            }
        } message: {
            if let pendingImport {
                Text(
                    "\(pendingImport.export.targets.count) 个检测目标。"
                        + pendingImport.mode.confirmationMessage
                )
            }
        }
        .alert(
            "配置导入导出失败",
            isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )
        ) {
            Button("确定", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "")
        }
        .confirmationDialog(
            "恢复所有内置目标？",
            isPresented: $showingRestoreConfirmation
        ) {
            Button("恢复内置目标") {
                model.restoreBuiltIns()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("内置目标的名称、类型、地址和启用状态将恢复默认。自定义目标不会受影响。")
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let export = try NetPulseConfigurationExport.load(from: url)
                guard export.appName == "NetPulse" else {
                    importError = "这不是 NetPulse 配置文件。"
                    return
                }
                guard export.schemaVersion <= NetPulseConfigurationExport.currentSchemaVersion else {
                    importError = "配置文件版本较新，请先升级 NetPulse。"
                    return
                }
                pendingImport = PendingConfigurationImport(export: export, mode: importMode)
            } catch {
                importError = "导入失败：\(error.localizedDescription)"
            }
        case .failure(let error):
            importError = "导入失败：\(error.localizedDescription)"
        }
    }
}

struct TargetManagerView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editingTarget: ProbeTarget?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(model.configuration.targets.count) 个检测目标")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            List {
                ForEach(model.orderedTargets) { target in
                    HStack(spacing: 12) {
                        Button {
                            editingTarget = target
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: target.category.symbol)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text(target.name)
                                        Text(target.service)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if target.isBuiltIn {
                                            Text("内置")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                        if !target.enabled {
                                            Text("已停用")
                                                .font(.caption2)
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                    Text(target.urlString)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 8)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .help("编辑 \(target.name)")

                        Button {
                            model.setTarget(target, pinned: !target.isPinned)
                        } label: {
                            Image(systemName: target.isPinned ? "pin.fill" : "pin")
                        }
                        .buttonStyle(.borderless)
                        .help(target.isPinned ? "取消置顶" : "置顶目标")

                        Menu {
                            Button {
                                editingTarget = target
                            } label: {
                                Label("编辑", systemImage: "pencil")
                            }

                            Button {
                                model.setTarget(target, enabled: !target.enabled)
                            } label: {
                                Label(
                                    target.enabled ? "停用" : "启用",
                                    systemImage: target.enabled
                                        ? "pause.circle"
                                        : "play.circle"
                                )
                            }

                            if !target.isBuiltIn {
                                Divider()
                                Button(role: .destructive) {
                                    model.deleteTarget(target)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundStyle(.secondary)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        .help("更多操作")
                    }
                    .padding(.vertical, 4)
                    .opacity(target.enabled ? 1 : 0.58)
                }
            }
            .listStyle(.inset)
        }
        .sheet(item: $editingTarget) { target in
            TargetEditorView(target: target)
        }
    }
}

struct RuntimeSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section("检测") {
                Toggle(
                    "启用周期检测",
                    isOn: Binding(
                        get: { model.configuration.scheduleEnabled },
                        set: { model.setScheduleEnabled($0) }
                    )
                )
                Stepper(
                    "检测间隔 \(model.configuration.intervalMinutes) 分钟",
                    value: Binding(
                        get: { model.configuration.intervalMinutes },
                        set: { model.setScheduleInterval($0) }
                    ),
                    in: 1...1_440
                )
                .disabled(!model.configuration.scheduleEnabled)
                Stepper(
                    "每项目采样 \(model.configuration.sampleCount) 次",
                    value: $model.configuration.sampleCount,
                    in: 1...8
                )
                Stepper(
                    "单次超时 \(Int(model.configuration.timeoutSeconds)) 秒",
                    value: $model.configuration.timeoutSeconds,
                    in: 2...15,
                    step: 1
                )
            }

            Section("提醒") {
                Toggle("异常时发送 macOS 通知", isOn: $model.configuration.notificationsEnabled)
                Toggle("恢复正常时通知", isOn: $model.configuration.notifyRecovery)
                    .disabled(!model.configuration.notificationsEnabled)
                Picker("重复提醒间隔", selection: $model.configuration.notificationCooldownMinutes) {
                    ForEach([5, 15, 30, 60, 120], id: \.self) {
                        Text("\($0) 分钟").tag($0)
                    }
                }
                Button {
                    model.testNotification()
                } label: {
                    Label("测试通知", systemImage: "bell")
                }
                Text(model.notificationPermission)
                    .font(.caption)
                    .foregroundStyle(
                        model.notificationPermission.contains("关闭") ? .red : .secondary
                    )
                if model.notificationPermission.contains("关闭") {
                    Button {
                        model.openNotificationSettings()
                    } label: {
                        Label("打开系统通知设置", systemImage: "gear")
                    }
                }
            }

            Section("启动") {
                Toggle(
                    "登录 macOS 后自动运行",
                    isOn: Binding(
                        get: { model.configuration.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    )
                )
                if let error = model.launchAtLoginError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .task {
            await model.refreshNotificationPermission()
        }
    }
}

struct HistoryPanelView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: "检测历史", symbol: "clock.arrow.circlepath") {
                dismiss()
            }
            Divider()
            HistoryView()
        }
        .frame(width: 680, height: 560)
    }
}

struct HistoryView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        if model.history.isEmpty {
            EmptyStateView(
                title: "暂无历史",
                symbol: "clock",
                detail: "检测完成后会保留最近 50 次结果。"
            )
        } else {
            List(model.history) { run in
                HStack(spacing: 14) {
                    StatusDot(status: run.status)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(run.finishedAt.formatted(date: .abbreviated, time: .standard))
                            .font(.body.weight(.medium))
                        Text("健康 \(run.healthyCount)/\(run.results.count) · 可用 \(run.availableCount)/\(run.results.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(formatMilliseconds(run.durationMs))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 5)
            }
            .listStyle(.inset)
        }
    }
}

struct TargetEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    private let target: ProbeTarget?

    @State private var service: String
    @State private var name: String
    @State private var category: ProbeCategory
    @State private var address: String
    @State private var enabled: Bool
    @State private var pinned: Bool

    init(target: ProbeTarget? = nil) {
        self.target = target
        _service = State(initialValue: target?.service ?? "")
        _name = State(initialValue: target?.name ?? "")
        _category = State(initialValue: target?.category ?? .custom)
        _address = State(initialValue: target?.urlString ?? "")
        _enabled = State(initialValue: target?.enabled ?? true)
        _pinned = State(initialValue: target?.isPinned ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(
                    target == nil ? "添加检测目标" : "编辑检测目标",
                    systemImage: target == nil ? "plus.circle" : "pencil"
                )
                .font(.title2.weight(.semibold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("关闭")
            }

            Form {
                Section {
                    TextField(
                        "服务分组",
                        text: $service,
                        prompt: Text("例如 Google、X、公司内网")
                    )
                    TextField(
                        "目标名称",
                        text: $name,
                        prompt: Text("例如 用户图片 CDN、登录接口")
                    )
                    Picker("内容类型（图标）", selection: $category) {
                        ForEach(ProbeCategory.allCases) { category in
                            Label(category.rawValue, systemImage: category.symbol)
                                .tag(category)
                        }
                    }
                } header: {
                    Text("列表呈现")
                } footer: {
                    Text("服务分组决定主面板顶部的筛选标签；目标名称显示为列表主标题；内容类型用于列表图标和用途标识。")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Section("访问地址") {
                    TextField(
                        "域名或 URL",
                        text: $address,
                        prompt: Text("example.com 或 https://example.com/path")
                    )
                }

                Section("显示与运行") {
                    Toggle("启用检测", isOn: $enabled)
                    Toggle("在“全部”列表中置顶", isOn: $pinned)
                }

                if target?.isBuiltIn == true {
                    Section {
                        Label(
                            "这是内置目标。修改服务、名称、类型或地址时，原有的状态码、内容类型和数据量判定规则仍会保留。",
                            systemImage: "checkmark.shield"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Text("需要撤销修改时，可从配置页顶部的更多菜单恢复内置目标。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("内置检测规则")
                    }
                }

                Section("列表预览") {
                    HStack(spacing: 12) {
                        Image(systemName: category.symbol)
                            .foregroundStyle(.secondary)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text(previewName)
                                    .font(.body.weight(.medium))
                                Text(previewService)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(previewAddress)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Text(target == nil ? "添加后在下一次检测时生效" : "保存后在下一次检测时生效")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(actionTitle) {
                    save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .padding(24)
        .frame(width: 580, height: target?.isBuiltIn == true ? 650 : 590)
    }

    private var actionTitle: String {
        target == nil ? "添加" : "保存"
    }

    private var canSave: Bool {
        !service.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        if let target {
            model.updateTarget(
                target,
                service: service,
                name: name,
                category: category,
                input: address,
                enabled: enabled,
                pinned: pinned
            )
        } else {
            model.addTarget(
                service: service,
                name: name,
                category: category,
                input: address,
                enabled: enabled,
                pinned: pinned
            )
        }
    }

    private var previewService: String {
        let value = service.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "服务分组" : value
    }

    private var previewName: String {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "目标名称" : value
    }

    private var previewAddress: String {
        let value = address.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "example.com" : value
    }
}

private struct PanelHeader: View {
    let title: String
    let symbol: String
    let close: () -> Void

    var body: some View {
        HStack {
            Label(title, systemImage: symbol)
                .font(.title2.weight(.semibold))
            Spacer()
            Button(action: close) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("关闭")
        }
        .padding(20)
    }
}
