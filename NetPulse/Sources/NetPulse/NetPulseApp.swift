import AppKit
import SwiftUI

@MainActor
final class NetPulseAppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let model = AppModel()
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController(model: model)
    }
}

@main
struct NetPulseApp: App {
    @NSApplicationDelegateAdaptor(NetPulseAppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("NetPulse", id: "dashboard") {
            DashboardView()
                .environmentObject(appDelegate.model)
        }
        .handlesExternalEvents(matching: ["dashboard"])
        .defaultSize(width: 980, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("检测") {
                Button("立即检测") {
                    appDelegate.model.runNow()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(appDelegate.model.isRunning)
            }
        }
    }
}
