import SwiftUI
import BackgroundTasks

@main
struct AzimuthApp: App {
    @State private var engine: AzimuthEngine
    @State private var router = TabRouter()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Register the BG task handler BEFORE any code path can reach
        // BGTaskScheduler.submit(). AzimuthEngine.init() calls
        // scheduleNextRefresh() when trackingEnabled is true, so the engine
        // singleton must be created strictly after this register() call.
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

        NotificationService.shared.installDelegate()
        _engine = State(initialValue: AzimuthEngine.shared)
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
