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
        guard authorization == .whenInUse || authorization == .always else { return }
        manager.startUpdatingLocation()
        manager.startMonitoringSignificantLocationChanges()
        manager.startMonitoringVisits()
        isUpdating = true
    }

    func stopUpdates() {
        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
        manager.stopMonitoringVisits()
        isUpdating = false
    }

    func requestOneShot() {
        guard authorization == .whenInUse || authorization == .always else { return }
        manager.requestLocation()
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
