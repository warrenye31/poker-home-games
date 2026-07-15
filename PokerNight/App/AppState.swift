import Foundation
import Observation

@Observable
final class AppState {
    /// The group the Sessions and Stats tabs are scoped to.
    ///
    /// This used to mirror its name into the App Group defaults on every change;
    /// that existed solely so the home-screen widget could title itself, and the
    /// widget was removed in 5fbe778. Nothing read the key afterwards.
    var selectedGroup: GameGroup?
}
