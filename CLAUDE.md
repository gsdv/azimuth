# Azimuth — working agreements

## Don't run the simulator

The dev runs the iOS Simulator themselves. Do not:
- boot, install, launch, terminate, or uninstall apps via `xcrun simctl`
- take screenshots via `xcrun simctl io ... screenshot`
- write to the simulator's defaults / privacy / location
- open the `Simulator.app`

`xcodebuild ... build` for syntax/type-checking is fine — that doesn't touch a running simulator. If UI behavior needs verification, describe what the code does and ask the user to confirm in their simulator.
