import SwiftUI

enum AppTab: Hashable {
    case track
    case recent
    case settings
}

struct ContentView: View {
    @Environment(TabRouter.self) private var router

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selection) {
            Tab("Track", systemImage: "location.north.line.fill", value: AppTab.track) {
                HomeView()
            }
            Tab("Recent", systemImage: "list.bullet.rectangle.fill", value: AppTab.recent) {
                RecentSendsView()
            }
            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView()
            }
        }
        .tint(Theme.skyDeep)
    }
}

#Preview {
    ContentView()
        .environment(AzimuthEngine())
        .environment(TabRouter())
}
