# Azimuth

A small iOS app that sends your device's location to an HTTP endpoint **you control**, on a schedule **you set**. No third-party server, no analytics, no tracking — your coordinates go from your phone straight to the URL you configure.

## What it does

When tracking is on, Azimuth wakes up on the schedule you choose, gets a location fix, and POSTs a JSON body to your endpoint. Each send is recorded locally (last 50) so you can see what was sent, when, and whether the endpoint accepted it.

### Payload

`POST <your-endpoint>` with `Content-Type: application/json` and (optionally) `Authorization: Bearer <your-token>`:

```json
{
  "locations": [
    {
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [-122.4194, 37.7749]
      },
      "properties": {
        "timestamp": "2026-05-06T12:34:56.789Z",
        "horizontal_accuracy": 10,
        "vertical_accuracy": 4,
        "altitude": 23,
        "device_id": "<uuid>",
        "speed": 0,
        "battery_level": 0.87,
        "battery_state": "unplugged"
      }
    }
  ],
  "current": { "...same feature as above..." }
}
```

Coordinates are `[longitude, latitude]` (GeoJSON order). `speed`, `battery_level`, and `battery_state` are only present if you've enabled them in Settings. The app expects any 2xx response to mean "accepted"; anything else is recorded as a failure.

## Features

- Schedules: hourly, every 6h, every 12h, daily at a chosen time, or weekly on a chosen day/time
- Background sends via `BGTaskScheduler` — works while the app is closed, subject to iOS's discretion
- Optional bearer token, stored in the iOS Keychain
- Toggle whether to include speed and battery
- "Send now" button for ad-hoc sends
- Local history of recent sends with status, timestamp, and any error
- Light/dark mode

## Requirements

- iOS 26.0 or later
- Xcode 26 or later
- A server that accepts the payload above (or a service that does — Azimuth is endpoint-agnostic)

## Build and run

1. Clone the repo and open `Azimuth.xcodeproj` in Xcode.
2. Select the `Azimuth` target → **Signing & Capabilities** and:
   - Set **Team** to your own Apple Developer team
   - Change **Bundle Identifier** to one you own (e.g. `com.yourname.azimuth`)
3. Update the matching background-task identifier in `Azimuth/Info.plist`:
   ```xml
   <key>BGTaskSchedulerPermittedIdentifiers</key>
   <array>
     <string>com.yourname.azimuth.refresh</string>
   </array>
   ```
   The identifier in `Info.plist` must equal `<your-bundle-id>.refresh`.
4. Build and run on a device. Background location and `BGTaskScheduler` don't fire reliably in the Simulator.

## Configure (in the app)

Open the **Settings** tab:

- **Endpoint URL** — required. Must be `http://` or `https://`. (`https://` strongly recommended.)
- **Bearer token** — optional. If set, sent as `Authorization: Bearer <token>` on every request.
- **Schedule** — pick one of the schedule kinds described above.
- **Include speed / Include battery** — toggle whether those fields are added to the payload.

Then go to the **Track** tab and tap the big button to start tracking. Tap again to stop.

The first time you start tracking, iOS will ask for "Always" location permission. Background sends won't work without it.

## Privacy

- Location data is sent only to the URL you configure. It does not pass through any server operated by the developer.
- Bearer tokens are stored in the iOS Keychain.
- The `device_id` field is a random UUID generated on first launch and stored in `UserDefaults`. It does not identify you across reinstalls.
- No analytics or crash-reporting SDKs are bundled.

## Project layout

```
Azimuth/
├─ AzimuthApp.swift            # App entry, BGTaskScheduler registration
├─ ContentView.swift           # Tab container (Track / Recent / Settings)
├─ Models/                     # AppSettings, SendSchedule, SendStatus, TabRouter
├─ Services/
│  ├─ AzimuthEngine.swift      # Orchestrates location → endpoint → history
│  ├─ LocationService.swift    # CoreLocation wrapper
│  ├─ EndpointService.swift    # Builds and POSTs the payload
│  ├─ KeychainStore.swift      # Bearer token storage
│  ├─ NotificationService.swift
│  └─ PendingQueue.swift       # Retry queue for failed sends
├─ Theme/Theme.swift           # Colors and gradients
└─ Views/                      # SwiftUI screens and components
```

## Contributing

Issues and PRs welcome. There are no automated tests yet; please describe how you verified your change in the PR.

## License

TODO — add a license. Until one is added, all rights are reserved by default and the code is not legally reusable.
