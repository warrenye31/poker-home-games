import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            GroupsListView()
                .tabItem { Label("Groups", systemImage: "person.3.fill") }
            SessionsHomeView()
                .tabItem { Label("Sessions", systemImage: "suit.spade.fill") }
            StatsHomeView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}
