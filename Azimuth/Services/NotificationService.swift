import Foundation
import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationService()

    @MainActor var pendingNavigation: AppTab?
    @MainActor var onTapOpenRecent: (@MainActor () -> Void)?

    private nonisolated static let openTabKey = "azimuth.openTab"
    private nonisolated static let recentValue = "recent"
    private nonisolated static let failureThreadID = "azimuth.send-failure"

    private override init() {
        super.init()
    }

    func installDelegate() {
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    func scheduleSendFailure(message: String) {
        let center = UNUserNotificationCenter.current()
        Task {
            let settings = await center.notificationSettings()
            let status = settings.authorizationStatus
            guard status == .authorized || status == .provisional || status == .ephemeral else { return }

            let content = UNMutableNotificationContent()
            content.title = "Azimuth send failed"
            content.body = message
            content.sound = .default
            content.threadIdentifier = NotificationService.failureThreadID
            content.userInfo = [NotificationService.openTabKey: NotificationService.recentValue]

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            try? await center.add(request)
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let openTab = response.notification.request.content.userInfo[NotificationService.openTabKey] as? String
        Task { @MainActor in
            if openTab == NotificationService.recentValue {
                if let handler = self.onTapOpenRecent {
                    handler()
                } else {
                    self.pendingNavigation = .recent
                }
            }
            completionHandler()
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}
