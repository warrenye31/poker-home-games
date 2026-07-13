import Foundation
import SwiftData

@Model
final class GameGroup {
    var name: String = ""
    var createdDate: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \Player.group)
    var players: [Player] = []

    @Relationship(deleteRule: .cascade, inverse: \Session.group)
    var sessions: [Session] = []

    init(name: String, createdDate: Date = .now) {
        self.name = name
        self.createdDate = createdDate
    }
}
