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

    private(set) var statuses: [UUID: SendStatus] = [:]
    private(set) var pendingCounts: [UUID: Int] = [:]

    private var foregroundTimer: Timer?
    private var inflightSends: Set<UUID> = []
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
            await self?.refreshAllPendingCounts()
        }
    }

    var isTracking: Bool { settings.trackingEnabled }

    var isAnySending: Bool {
        statuses.values.contains { $0.isSending }
    }

    var nextSendDate: Date? {
        guard settings.trackingEnabled else { return nil }
        return settings.earliestNextSendDate
    }

    var aggregateLastSentDate: Date? {
        settings.endpoints.compactMap { $0.lastSentDate }.max()
    }

    var aggregateStatus: SendStatus {
        if statuses.values.contains(where: { $0.isSending }) { return .sending }
        let dated: [(Date, SendStatus)] = statuses.values.compactMap { value in
            switch value {
            case .success(let d):       return (d, value)
            case .failure(_, let d):    return (d, value)
            case .sending, .idle:       return nil
            }
        }
        return dated.max(by: { $0.0 < $1.0 })?.1 ?? .idle
    }

    func status(for endpointID: UUID) -> SendStatus {
        statuses[endpointID] ?? .idle
    }

    func pendingCount(for endpointID: UUID) -> Int {
        pendingCounts[endpointID] ?? 0
    }

    var totalPendingCount: Int {
        pendingCounts.values.reduce(0, +)
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
        for id in inflightSends {
            if statuses[id]?.isSending == true {
                statuses[id] = .idle
            }
        }
        inflightSends.removeAll()
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.refreshTaskID)
    }

    func sendNow(endpointID: UUID) {
        guard let endpoint = settings.endpoint(id: endpointID) else { return }
        guard !inflightSends.contains(endpointID) else { return }
        location.requestOneShot()
        inflightSends.insert(endpointID)
        statuses[endpointID] = .sending
        Task { [weak self] in
            guard let self else { return }
            if let loc = await self.waitForRecentLocation(timeout: 8) {
                await self.performSend(endpoint: endpoint, location: loc)
            } else if let cached = self.location.lastLocation {
                await self.performSend(endpoint: endpoint, location: cached)
            } else {
                self.statuses[endpointID] = .failure(message: "Couldn't get a location fix.", at: Date())
            }
            self.inflightSends.remove(endpointID)
        }
    }

    func sendAllDueNow(force: Bool = false) {
        let now = Date()
        let targets: [Endpoint]
        if force {
            targets = settings.endpoints.filter { $0.isActive && $0.hasValidURL }
        } else {
            targets = settings.endpoints.filter { $0.shouldSend(now: now) }
        }
        guard !targets.isEmpty else { return }
        location.requestOneShot()
        for ep in targets {
            guard !inflightSends.contains(ep.id) else { continue }
            inflightSends.insert(ep.id)
            statuses[ep.id] = .sending
            Task { [weak self] in
                guard let self else { return }
                if let loc = await self.waitForRecentLocation(timeout: 8) {
                    await self.performSend(endpoint: ep, location: loc)
                } else if let cached = self.location.lastLocation {
                    await self.performSend(endpoint: ep, location: cached)
                } else {
                    self.statuses[ep.id] = .failure(message: "Couldn't get a location fix.", at: Date())
                }
                self.inflightSends.remove(ep.id)
            }
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
        guard let loc = location.lastLocation else { return }
        let now = Date()
        let due = settings.endpoints.filter { $0.shouldSend(now: now) }
        for ep in due {
            guard !inflightSends.contains(ep.id) else { continue }
            inflightSends.insert(ep.id)
            Task { [weak self] in
                await self?.performSend(endpoint: ep, location: loc)
                self?.inflightSends.remove(ep.id)
            }
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
                guard self.settings.trackingEnabled else { return }
                let now = Date()
                let anyDue = self.settings.endpoints.contains { $0.shouldSend(now: now) }
                if anyDue { self.location.requestOneShot() }
            }
        }
    }

    private static let maxBodyPreviewBytes = 16 * 1024

    private static func bodyPreview(from data: Data) -> (json: String, truncated: Bool) {
        if data.count > maxBodyPreviewBytes {
            let raw = String(data: data.prefix(maxBodyPreviewBytes), encoding: .utf8) ?? ""
            return (raw, true)
        }
        if let obj = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: pretty, encoding: .utf8) {
            return (str, false)
        }
        return (String(data: data, encoding: .utf8) ?? "", false)
    }

    private func performSend(endpoint ep: Endpoint, location loc: CLLocation) async {
        guard ep.hasValidURL else {
            statuses[ep.id] = .failure(message: "Endpoint URL is invalid.", at: Date())
            return
        }

        statuses[ep.id] = .sending
        let battery = ep.includeBattery ? readBattery() : (nil, nil)
        let payload = EndpointPayload(
            location: loc,
            deviceId: settings.deviceId,
            includeSpeed: ep.includeSpeed,
            batteryLevel: battery.0,
            batteryState: battery.1
        )
        let url = ep.url
        let token = settings.bearerToken(for: ep.id)
        let bearer: String? = token.isEmpty ? nil : token

        let body: Data
        do {
            body = try EndpointService.encode(payload: payload)
        } catch {
            let now = Date()
            let message = "Couldn't encode payload."
            statuses[ep.id] = .failure(message: message, at: now)
            settings.recordSend(SendRecord(
                date: now, success: false, statusCode: nil,
                message: error.localizedDescription,
                endpointID: ep.id, endpointName: ep.displayName,
                bodyJSON: nil, bodyTruncated: false
            ))
            NotificationService.shared.scheduleSendFailure(message: "\(ep.displayName): \(message)")
            return
        }

        let preview = AzimuthEngine.bodyPreview(from: body)

        let bgTaskID = UIApplication.shared.beginBackgroundTask(withName: "AzimuthSend")
        defer {
            if bgTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(bgTaskID)
            }
        }

        do {
            let result = try await endpoint.send(body: body, to: url, bearerToken: bearer)
            let now = Date()
            statuses[ep.id] = .success(at: now)
            settings.recordSend(SendRecord(
                date: now, success: true, statusCode: result.statusCode,
                message: nil,
                endpointID: ep.id, endpointName: ep.displayName,
                bodyJSON: preview.json, bodyTruncated: preview.truncated
            ))
            flushPending(for: ep.id)
            scheduleNextRefresh()
        } catch let error as EndpointError {
            let now = Date()
            let message = error.errorDescription ?? "Send failed."
            statuses[ep.id] = .failure(message: message, at: now)
            let code: Int? = {
                if case .httpStatus(let c) = error { return c }
                return nil
            }()
            if case .networkFailure = error {
                await pending.enqueue(endpointID: ep.id, body: body, capturedAt: loc.timestamp)
                pendingCounts[ep.id] = await pending.count(forEndpoint: ep.id)
            }
            settings.recordSend(SendRecord(
                date: now, success: false, statusCode: code, message: message,
                endpointID: ep.id, endpointName: ep.displayName,
                bodyJSON: preview.json, bodyTruncated: preview.truncated
            ))
            NotificationService.shared.scheduleSendFailure(message: "\(ep.displayName): \(message)")
        } catch {
            let now = Date()
            let message = error.localizedDescription
            statuses[ep.id] = .failure(message: message, at: now)
            await pending.enqueue(endpointID: ep.id, body: body, capturedAt: loc.timestamp)
            pendingCounts[ep.id] = await pending.count(forEndpoint: ep.id)
            settings.recordSend(SendRecord(
                date: now, success: false, statusCode: nil, message: message,
                endpointID: ep.id, endpointName: ep.displayName,
                bodyJSON: preview.json, bodyTruncated: preview.truncated
            ))
            NotificationService.shared.scheduleSendFailure(message: "\(ep.displayName): \(message)")
        }
    }

    func flushPending(for endpointID: UUID? = nil) {
        guard flushTask == nil else { return }
        let endpointSnapshot = settings.endpoints

        flushTask = Task { [weak self] in
            guard let self else { return }
            let bgTaskID = UIApplication.shared.beginBackgroundTask(withName: "AzimuthFlush")
            defer {
                if bgTaskID != .invalid {
                    UIApplication.shared.endBackgroundTask(bgTaskID)
                }
            }

            let allItems = await self.pending.snapshot()
            let items: [PendingQueue.Item]
            if let endpointID {
                items = allItems.filter { $0.endpointID == endpointID }
            } else {
                items = allItems
            }

            for item in items {
                guard let ep = endpointSnapshot.first(where: { $0.id == item.endpointID }),
                      ep.hasValidURL else {
                    await self.pending.remove(id: item.id)
                    continue
                }
                let token = self.settings.bearerToken(for: ep.id)
                let bearer: String? = token.isEmpty ? nil : token
                do {
                    _ = try await self.endpoint.send(body: item.body, to: ep.url, bearerToken: bearer)
                    await self.pending.remove(id: item.id)
                } catch {
                    break
                }
            }
            await self.refreshAllPendingCounts()
            self.flushTask = nil
        }
    }

    private func refreshAllPendingCounts() async {
        var fresh: [UUID: Int] = [:]
        let snap = await pending.snapshot()
        for item in snap {
            fresh[item.endpointID, default: 0] += 1
        }
        self.pendingCounts = fresh
    }

    func didEnterForeground() {
        flushPending()
        guard settings.trackingEnabled else { return }
        let now = Date()
        let anyDue = settings.endpoints.contains { $0.shouldSend(now: now) }
        if anyDue { location.requestOneShot() }
    }

    func scheduleNextRefresh() {
        guard settings.trackingEnabled else { return }
        guard settings.hasAnyActiveValidEndpoint else { return }
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskID)
        let target = settings.earliestNextSendDate ?? Date().addingTimeInterval(60 * 60)
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
                  self.settings.hasAnyActiveValidEndpoint else { return }
            let now = Date()
            let anyDue = self.settings.endpoints.contains { $0.shouldSend(now: now) }
            guard anyDue else { return }
            self.location.requestOneShot()
            let start = Date()
            while Date().timeIntervalSince(start) < 20 {
                if Task.isCancelled { return }
                let stillDue = self.settings.endpoints.contains { $0.shouldSend(now: Date()) }
                if !stillDue { return }
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
