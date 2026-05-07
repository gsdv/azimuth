import Foundation
import CoreLocation
import Observation

@MainActor
@Observable
final class LocationService: NSObject {
    enum Authorization {
        case notDetermined
        case denied
        case whenInUse
        case always
        case restricted
    }

    private let manager = CLLocationManager()

    private(set) var authorization: Authorization = .notDetermined
    private(set) var lastLocation: CLLocation?
    private(set) var isUpdating: Bool = false

    private var wantsForegroundUpdates = false
    private var wantsTrackingUpdates = false

    var onLocation: ((CLLocation) -> Void)?
    var onAuthorizationChange: ((Authorization) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 50
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        #if os(iOS)
        manager.showsBackgroundLocationIndicator = false
        #endif
        syncAuthorization(manager.authorizationStatus)
    }

    func requestPermission() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    func startUpdates() {
        wantsTrackingUpdates = true
        syncManagerState()
    }

    func stopUpdates() {
        wantsTrackingUpdates = false
        syncManagerState()
    }

    func startForegroundUpdates() {
        wantsForegroundUpdates = true
        syncManagerState()
    }

    func stopForegroundUpdates() {
        wantsForegroundUpdates = false
        syncManagerState()
    }

    func requestOneShot() {
        guard authorization == .whenInUse || authorization == .always else { return }
        manager.requestLocation()
    }

    private func syncManagerState() {
        let authorized = authorization == .whenInUse || authorization == .always
        guard authorized else {
            if isUpdating {
                manager.stopUpdatingLocation()
                manager.stopMonitoringSignificantLocationChanges()
                manager.stopMonitoringVisits()
                isUpdating = false
            }
            return
        }
        let wantsContinuous = wantsForegroundUpdates || wantsTrackingUpdates
        if wantsContinuous {
            manager.startUpdatingLocation()
        } else {
            manager.stopUpdatingLocation()
        }
        if wantsTrackingUpdates {
            manager.startMonitoringSignificantLocationChanges()
            manager.startMonitoringVisits()
        } else {
            manager.stopMonitoringSignificantLocationChanges()
            manager.stopMonitoringVisits()
        }
        isUpdating = wantsContinuous
    }

    private func syncAuthorization(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:    authorization = .notDetermined
        case .restricted:       authorization = .restricted
        case .denied:           authorization = .denied
        case .authorizedWhenInUse: authorization = .whenInUse
        case .authorizedAlways: authorization = .always
        @unknown default:       authorization = .notDetermined
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            let previous = self.authorization
            self.syncAuthorization(status)
            self.syncManagerState()
            if self.authorization != previous {
                self.onAuthorizationChange?(self.authorization)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.lastLocation = loc
            self.onLocation?(loc)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Swallow transient errors; CLLocationManager will retry.
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        Task { @MainActor in
            self.manager.requestLocation()
        }
    }
}
