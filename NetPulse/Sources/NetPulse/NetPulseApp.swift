import SwiftUI

@main
struct NetPulseApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(model)
        } label: {
            NetworkPulseMenuBarIcon(
                status: model.overallStatus,
                isRunning: model.isRunning
            )
        }
        .menuBarExtraStyle(.window)

        Window("NetPulse", id: "dashboard") {
            DashboardView()
                .environmentObject(model)
        }
        .handlesExternalEvents(matching: ["dashboard"])
        .defaultSize(width: 980, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("检测") {
                Button("立即检测") {
                    model.runNow()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(model.isRunning)
            }
        }
    }
}
