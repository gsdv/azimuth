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
            Tab(value: AppTab.track) {
                HomeView()
            } label: {
                Label("Track", systemImage: "location.north.fill")
                    .labelStyle(.iconOnly)
            }
            Tab(value: AppTab.recent) {
                RecentSendsView()
            } label: {
                Label("Recent", systemImage: "list.bullet.rectangle.fill")
                    .labelStyle(.iconOnly)
            }
            Tab(value: AppTab.settings) {
                SettingsView()
            } label: {
                Label("Settings", systemImage: "gearshape.fill")
                    .labelStyle(.iconOnly)
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
