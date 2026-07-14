import SwiftUI
import SwiftData

/// Re-enters an already-running session at the live table so an in-progress
/// game can be picked back up, cashed out, and settled — without ever landing
/// on the settlement screen while the session is still unbalanced.
struct ResumeSessionFlowView: View {
    let session: Session

    @Environment(\.dismiss) private var dismiss
    @State private var path: [ResumeStep] = []

    var body: some View {
        NavigationStack(path: $path) {
            LiveSessionView(session: session) { path.append(.end) }
                .navigationDestination(for: ResumeStep.self) { step in
                    switch step {
                    case .end:
                        EndSessionView(session: session) { path.append(.settlement) }
                    case .settlement:
                        SettlementView(session: session, onDone: { dismiss() })
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
        }
    }

    private enum ResumeStep: Hashable {
        case end
        case settlement
    }
}
