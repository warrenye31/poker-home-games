import SwiftUI
import SwiftData

@main
struct PokerNightApp: App {
    let container: ModelContainer = {
        let schema = Schema([
            GameGroup.self,
            Player.self,
            Session.self,
            SessionEntry.self,
            BuyIn.self,
            SettlementPayment.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private("iCloud.com.pokernight.app")
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

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
