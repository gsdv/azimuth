import Foundation
import CoreLocation
import Observation
import UIKit
import BackgroundTasks

@MainActor
@Observable
final class AzimuthEngine {
    static let shared = AzimuthEngine()
    static let refreshTaskID = "me.gsdv.azimuth.refresh"

    let settings: AppSettings
    let location: LocationService
    private let endpoint: EndpointService
    private let pending: PendingQueue

    private(set) var status: SendStatus = .idle
    private(set) var pendingCount: Int = 0

    private var foregroundTimer: Timer?
    private var sendTask: Task<Void, Never>?
    private var flushTask: Task<Void, Never>?

    init(settings: AppSettings? = nil,
         location: LocationService? = nil,
         endpoint: EndpointService = EndpointService(),
         pending: PendingQueue = PendingQueue()) {
        self.settings = settings ?? AppSettings()
        self.location = location ?? LocationService()
        self.endpoint = endpoint
        self.pending = pending

        self.location.onLocation = { [weak self] _ in
            self?.handleLocationUpdate()
        }

        self.location.onAuthorizationChange = { [weak self] auth in
            self?.handleAuthorizationChange(auth)
        }

        if self.settings.trackingEnabled {
            startTracking()
        }

        Task { [weak self] in
            guard let self else { return }
            self.pendingCount = await self.pending.count()
        }
    }

    var isTracking: Bool { settings.trackingEnabled }

    var nextSendDate: Date? {
        guard settings.trackingEnabled else { return nil }
        let reference = settings.lastSentDate ?? Date()
        return settings.schedule.nextDate(after: reference)
    }

    func toggleTracking() {
        if settings.trackingEnabled {
            stopTracking()
        } else {
            startTracking()
        }
    }

    func startTracking() {
        settings.trackingEnabled = true
        if location.authorization == .notDetermined {
            location.requestPermission()
        }
        Task { _ = await NotificationService.shared.requestAuthorization() }
        location.startUpdates()
        scheduleForegroundTick()
        scheduleNextRefresh()
    }

    func stopTracking() {
        settings.trackingEnabled = false
        location.stopUpdates()
        foregroundTimer?.invalidate()
        foregroundTimer = nil
        sendTask?.cancel()
        sendTask = nil
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.refreshTaskID)
        if status.isSending { status = .idle }
    }

    func sendNow() {
        guard sendTask == nil else { return }
        location.requestOneShot()
        sendTask = Task { [weak self] in
            guard let self else { return }
            if let loc = await waitForRecentLocation(timeout: 8) {
                await self.performSend(location: loc, recordEvenWhenManual: true)
            } else if let cached = self.location.lastLocation {
                await self.performSend(location: cached, recordEvenWhenManual: true)
            } else {
                self.status = .failure(message: "Couldn't get a location fix.", at: Date())
            }
            self.sendTask = nil
        }
    }

    private func waitForRecentLocation(timeout: TimeInterval) async -> CLLocation? {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if let loc = location.lastLocation,
               loc.timestamp.timeIntervalSinceNow > -10 {
                return loc
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return location.lastLocation
    }

    private func handleLocationUpdate() {
        guard settings.trackingEnabled else { return }
        guard shouldSend() else { return }
        guard sendTask == nil else { return }
        guard let loc = location.lastLocation else { return }
        sendTask = Task { [weak self] in
            await self?.performSend(location: loc, recordEvenWhenManual: false)
            self?.sendTask = nil
        }
    }

    private func handleAuthorizationChange(_ auth: LocationService.Authorization) {
        guard settings.trackingEnabled else { return }
        if auth == .whenInUse || auth == .always {
            location.startUpdates()
            scheduleForegroundTick()
        }
    }

    private func scheduleForegroundTick() {
        foregroundTimer?.invalidate()
        foregroundTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.settings.trackingEnabled, self.shouldSend() else { return }
                self.location.requestOneShot()
            }
        }
    }

    private func shouldSend() -> Bool {
        guard let last = settings.lastSentDate else { return true }
        return Date() >= settings.schedule.nextDate(after: last)
    }

    private func performSend(location loc: CLLocation, recordEvenWhenManual: Bool) async {
        guard settings.hasValidEndpoint else {
            status = .failure(message: "Set an endpoint in Settings first.", at: Date())
            return
        }

        status = .sending
        let battery = settings.includeBattery ? readBattery() : (nil, nil)
        let payload = EndpointPayload(
            location: loc,
            deviceId: settings.deviceId,
            includeSpeed: settings.includeSpeed,
            batteryLevel: battery.0,
            batteryState: battery.1
        )
        let url = settings.endpointURL
        let token = settings.bearerToken
        let bearer: String? = token.isEmpty ? nil : token

        let body: Data
        do {
            body = try EndpointService.encode(payload: payload)
        } catch {
            let now = Date()
            let message = "Couldn't encode payload."
            status = .failure(message: message, at: now)
            settings.recordSend(SendRecord(date: now, success: false, statusCode: nil, message: error.localizedDescription))
            NotificationService.shared.scheduleSendFailure(message: message)
            return
        }

        let bgTaskID = UIApplication.shared.beginBackgroundTask(withName: "AzimuthSend")
        defer {
            if bgTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(bgTaskID)
            }
        }

        do {
            let result = try await endpoint.send(body: body, to: url, bearerToken: bearer)
            let now = Date()
            status = .success(at: now)
            settings.recordSend(SendRecord(date: now, success: true, statusCode: result.statusCode, message: nil))
            flushPending()
            scheduleNextRefresh()
        } catch let error as EndpointError {
            let now = Date()
            let message = error.errorDescription ?? "Send failed."
            status = .failure(message: message, at: now)
            let code: Int? = {
                if case .httpStatus(let c) = error { return c }
                return nil
            }()
            if case .networkFailure = error {
                await pending.enqueue(body: body, capturedAt: loc.timestamp)
                pendingCount = await pending.count()
            }
            settings.recordSend(SendRecord(date: now, success: false, statusCode: code, message: message))
            NotificationService.shared.scheduleSendFailure(message: message)
        } catch {
            let now = Date()
            let message = error.localizedDescription
            status = .failure(message: message, at: now)
            await pending.enqueue(body: body, capturedAt: loc.timestamp)
            pendingCount = await pending.count()
            settings.recordSend(SendRecord(date: now, success: false, statusCode: nil, message: message))
            NotificationService.shared.scheduleSendFailure(message: message)
        }
    }

    func flushPending() {
        guard flushTask == nil else { return }
        guard settings.hasValidEndpoint else { return }
        let url = settings.endpointURL
        let token = settings.bearerToken
        let bearer: String? = token.isEmpty ? nil : token

        flushTask = Task { [weak self] in
            guard let self else { return }
            let bgTaskID = UIApplication.shared.beginBackgroundTask(withName: "AzimuthFlush")
            defer {
                if bgTaskID != .invalid {
                    UIApplication.shared.endBackgroundTask(bgTaskID)
                }
            }

            let items = await self.pending.snapshot()
            for item in items {
                do {
                    _ = try await self.endpoint.send(body: item.body, to: url, bearerToken: bearer)
                    await self.pending.remove(id: item.id)
                } catch {
                    break
                }
            }
            self.pendingCount = await self.pending.count()
            self.flushTask = nil
        }
    }

    func didEnterForeground() {
        flushPending()
        guard settings.trackingEnabled, shouldSend(), sendTask == nil else { return }
        location.requestOneShot()
    }

    func scheduleNextRefresh() {
        guard settings.trackingEnabled else { return }
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskID)
        let target = nextSendDate ?? Date().addingTimeInterval(60 * 60)
        request.earliestBeginDate = max(target, Date().addingTimeInterval(15 * 60))
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // BGTaskScheduler.Error.notPermitted (background refresh disabled or simulator)
            // BGTaskScheduler.Error.tooManyPendingTaskRequests (already scheduled)
            // BGTaskScheduler.Error.unavailable
            // All non-fatal — refreshes are best-effort.
        }
    }

    func handleBackgroundRefresh(_ task: BGAppRefreshTask) async {
        let work = Task { @MainActor [weak self] in
            guard let self else { return }
            self.scheduleNextRefresh()
            guard self.settings.trackingEnabled,
                  self.settings.hasValidEndpoint,
                  self.shouldSend() else { return }
            self.location.requestOneShot()
            let start = Date()
            while Date().timeIntervalSince(start) < 20 {
                if Task.isCancelled { return }
                if !self.shouldSend() { return }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
        task.expirationHandler = {
            work.cancel()
        }
        _ = await work.value
        task.setTaskCompleted(success: true)
    }

    private func readBattery() -> (Double?, String?) {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        let levelOut: Double? = level >= 0 ? Double(round(level * 100) / 100) : nil
        let stateOut: String
        switch UIDevice.current.batteryState {
        case .charging:  stateOut = "charging"
        case .full:      stateOut = "full"
        case .unplugged: stateOut = "unplugged"
        case .unknown:   stateOut = "unknown"
        @unknown default: stateOut = "unknown"
        }
        return (levelOut, stateOut)
    }
}
