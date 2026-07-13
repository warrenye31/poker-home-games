import SwiftUI
import SwiftData

@main
struct PokerNightApp: App {
    let container: ModelContainer = SharedModelContainer.make()

    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(appState)
                .preferredColorScheme(.dark)
                .tint(AppTheme.accent)
        }
        .modelContainer(container)
    }
}
