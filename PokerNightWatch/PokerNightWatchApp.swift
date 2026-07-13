import SwiftUI
import SwiftData

@main
struct PokerNightWatchApp: App {
    let container: ModelContainer = SharedModelContainer.make()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .preferredColorScheme(.dark)
                .tint(AppTheme.accent)
        }
        .modelContainer(container)
    }
}
