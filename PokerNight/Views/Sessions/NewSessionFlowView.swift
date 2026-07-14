import SwiftUI
import SwiftData

private enum SessionFlowStep: Hashable {
    case review(NewSessionDraft)
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
            SessionSetupView(group: group) { draft in
                path.append(.review(draft))
            }
            .navigationDestination(for: SessionFlowStep.self) { step in
                switch step {
                case .review(let draft):
                    SessionReviewView(group: group, draft: draft) { newSession in
                        path.append(.live(newSession))
                    }
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
