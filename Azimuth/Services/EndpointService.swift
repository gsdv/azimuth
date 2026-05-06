import Foundation
import CoreLocation

struct EndpointPayload {
    var location: CLLocation
    var deviceId: String
    var includeSpeed: Bool
    var batteryLevel: Double?
    var batteryState: String?
}

enum EndpointError: LocalizedError {
    case invalidURL
    case networkFailure(String)
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Endpoint URL is invalid."
        case .networkFailure(let message):
            return message
        case .httpStatus(let code):
            return "Endpoint returned HTTP \(code)."
        }
    }
}

struct EndpointResult {
    var statusCode: Int
}

actor EndpointService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(payload: EndpointPayload, to urlString: String, bearerToken: String?) async throws -> EndpointResult {
        let body = try Self.encode(payload: payload)
        return try await send(body: body, to: urlString, bearerToken: bearerToken)
    }

    func send(body: Data, to urlString: String, bearerToken: String?) async throws -> EndpointResult {
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host?.isEmpty == false else {
            throw EndpointError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Azimuth/1.0 iOS", forHTTPHeaderField: "User-Agent")
        if let token = bearerToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body
        request.timeoutInterval = 30

        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw EndpointError.networkFailure("Invalid response.")
            }
            guard (200..<300).contains(http.statusCode) else {
                throw EndpointError.httpStatus(http.statusCode)
            }
            return EndpointResult(statusCode: http.statusCode)
        } catch let error as EndpointError {
            throw error
        } catch {
            throw EndpointError.networkFailure(error.localizedDescription)
        }
    }

    static func encode(payload: EndpointPayload) throws -> Data {
        let loc = payload.location
        let timestampFormatter = ISO8601DateFormatter()
        timestampFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = timestampFormatter.string(from: loc.timestamp)

        var properties: [String: Any] = [
            "timestamp": timestamp,
            "horizontal_accuracy": Int(loc.horizontalAccuracy.rounded()),
            "vertical_accuracy": Int(loc.verticalAccuracy.rounded()),
            "altitude": Int(loc.altitude.rounded()),
            "device_id": payload.deviceId
        ]
        if payload.includeSpeed, loc.speed >= 0 {
            properties["speed"] = Int(loc.speed.rounded())
        }
        if let level = payload.batteryLevel {
            properties["battery_level"] = level
        }
        if let state = payload.batteryState {
            properties["battery_state"] = state
        }

        let feature: [String: Any] = [
            "type": "Feature",
            "geometry": [
                "type": "Point",
                "coordinates": [
                    roundedCoord(loc.coordinate.longitude),
                    roundedCoord(loc.coordinate.latitude)
                ]
            ],
            "properties": properties
        ]

        let envelope: [String: Any] = [
            "locations": [feature],
            "current": feature
        ]

        return try JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])
    }

    private static func roundedCoord(_ value: Double) -> Double {
        (value * 10_000_000).rounded() / 10_000_000
    }
}
