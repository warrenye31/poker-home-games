import SwiftUI
import SwiftData

private enum SessionFlowStep: Hashable {
    case live, end, settlement
}

struct NewSessionFlowView: View {
    let group: GameGroup

    @Environment(\.dismiss) private var dismiss
    @State private var path: [SessionFlowStep] = []
    @State private var session: Session?

    var body: some View {
        NavigationStack(path: $path) {
            SessionSetupView(group: group) { newSession in
                session = newSession
                path.append(.live)
            }
            .navigationDestination(for: SessionFlowStep.self) { step in
                if let session {
                    switch step {
                    case .live:
                        LiveSessionView(session: session) { path.append(.end) }
                    case .end:
                        EndSessionView(session: session) { path.append(.settlement) }
                    case .settlement:
                        SettlementView(session: session, onDone: { dismiss() })
                    }
                }
            }
        }
    }
}
