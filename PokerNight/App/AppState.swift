import Foundation
import Observation

@Observable
final class AppState {
    var selectedGroup: GameGroup? {
        didSet {
            SharedModelContainer.sharedDefaults?.set(
                selectedGroup?.name,
                forKey: SharedModelContainer.selectedGroupNameKey
            )
        }
    }
}
