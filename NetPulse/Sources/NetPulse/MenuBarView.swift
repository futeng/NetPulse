import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                StatusDot(status: model.menuBarStatus)
                Text(model.isAnyProbeRunning ? "检测中" : model.menuBarStatus.title)
                    .font(.headline)
                Spacer()
                if let run = model.currentRun {
                    Text(run.finishedAt.formatted(date: .omitted, time: .shortened))
                        .foregroundStyle(.secondary)
                }
            }

            if let run = model.currentRun {
                Text("健康 \(run.healthyCount)/\(run.results.count) · 可用 \(run.availableCount)/\(run.results.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if model.notificationPermission.contains("关闭") {
                Button {
                    model.openNotificationSettings()
                } label: {
                    Label("通知未开启", systemImage: "bell.slash.fill")
                        .foregroundStyle(.red)
                }
            }

            Divider()

            Button {
                model.runNow()
            } label: {
                Label("立即检测", systemImage: "play.fill")
            }
            .disabled(model.isAnyProbeRunning)

            Button {
                openWindow(id: "dashboard")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("打开面板", systemImage: "macwindow")
            }

            Divider()

            Button("退出 NetPulse") {
                NSApp.terminate(nil)
            }
        }
        .padding(10)
        .frame(width: 260)
    }
}
