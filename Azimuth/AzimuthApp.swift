import SwiftUI
import BackgroundTasks

@main
struct AzimuthApp: App {
    @State private var engine = AzimuthEngine.shared
    @State private var router = TabRouter()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        _ = AzimuthEngine.shared
        NotificationService.shared.installDelegate()
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: AzimuthEngine.refreshTaskID,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in
                await AzimuthEngine.shared.handleBackgroundRefresh(refreshTask)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(engine)
                .environment(router)
                .task {
                    GlobalKeyboardDismisser.shared.install()
                    NotificationService.shared.onTapOpenRecent = {
                        router.selection = .recent
                    }
                    if let pending = NotificationService.shared.pendingNavigation {
                        router.selection = pending
                        NotificationService.shared.pendingNavigation = nil
                    }
                    if engine.isTracking {
                        engine.scheduleNextRefresh()
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        GlobalKeyboardDismisser.shared.install()
                        engine.didEnterForeground()
                    } else if phase == .background {
                        if engine.isTracking {
                            engine.scheduleNextRefresh()
                        }
                    }
                }
        }
    }
}
