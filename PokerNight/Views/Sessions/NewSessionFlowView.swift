import SwiftUI
import SwiftData

private enum SessionFlowStep: Hashable {
    case live(Session)
    case end(Session)
    case settlement(Session)
}

struct NewSessionFlowView: View {
    let group: GameGroup

    @Environment(\.dismiss) private var dismiss
    @State private var path: [SessionFlowStep] = []

    var body: some View {
        NavigationStack(path: $path) {
            SessionSetupView(group: group) { session in
                path.append(.live(session))
            }
            .navigationDestination(for: SessionFlowStep.self) { step in
                switch step {
                case .live(let session):
                    LiveSessionView(session: session) { path.append(.end(session)) }
                case .end(let session):
                    EndSessionView(session: session) { path.append(.settlement(session)) }
                case .settlement(let session):
                    SettlementView(session: session, onDone: { dismiss() })
                }
            }
        }
    }
}
