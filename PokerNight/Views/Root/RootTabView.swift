import SwiftUI
import SwiftData

struct RootTabView: View {
    @Query private var groups: [GameGroup]
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var isPresentingOnboarding = false

    var body: some View {
        TabView {
            GroupsListView()
                .tabItem { Label("Groups", systemImage: "person.3.fill") }
            SessionsHomeView()
                .tabItem { Label("Sessions", systemImage: "suit.spade.fill") }
            StatsHomeView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
            // Every other tab is scoped to a single group; this one crosses them.
            MeHomeView()
                .tabItem { Label("Me", systemImage: "person.crop.circle.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .onAppear {
            if !hasSeenOnboarding && groups.isEmpty {
                isPresentingOnboarding = true
            }
        }
        .sheet(isPresented: $isPresentingOnboarding, onDismiss: { hasSeenOnboarding = true }) {
            OnboardingView()
        }
    }
}
