import Foundation
import Observation
import WidgetKit

@Observable
final class AppState {
    var selectedGroup: GameGroup? {
        didSet {
            SharedModelContainer.sharedDefaults?.set(
                selectedGroup?.name,
                forKey: SharedModelContainer.selectedGroupNameKey
            )
            WidgetCenter.shared.reloadTimelines(ofKind: SharedModelContainer.widgetKind)
        }
    }
}
