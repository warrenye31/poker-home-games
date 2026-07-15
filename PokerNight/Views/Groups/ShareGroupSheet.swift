import SwiftUI
import UIKit

/// Admin-only sheet: publishes the group to Supabase (if not already shared)
/// and displays the join code others can use to view it read-only.
struct ShareGroupSheet: View {
    @Bindable var group: GameGroup

    @Environment(\.dismiss) private var dismiss
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if isWorking {
                    ProgressView("Publishing group…")
                        .padding(.top, 40)
                } else if let code = group.joinCode {
                    codeCard(code)
                } else if let errorMessage {
                    errorCard(errorMessage)
                }
                Spacer()
            }
            .padding(20)
            .appScreenBackground()
            .navigationTitle("Share \(group.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await shareIfNeeded() }
        }
    }

    private func codeCard(_ code: String) -> some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                SectionLabel("Join code")
                Text(code)
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .tracking(4)
                    .monospaced()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .cardBackground()

            Text("Anyone with this code can view \(group.name)'s stats — they can't edit players or sessions.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                ShareLink(item: shareText(code: code)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.pill(prominent: true))

                Button {
                    UIPasteboard.general.string = code
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.pill(prominent: false))
            }

            if let lastSyncedAt = group.lastSyncedAt {
                Text("Last synced \(lastSyncedAt.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await shareIfNeeded(force: true) }
            } label: {
                Label("Sync now", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.pill(prominent: false))
        }
    }

    private func errorCard(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.accent)
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Try again") {
                Task { await shareIfNeeded(force: true) }
            }
            .buttonStyle(.pill(prominent: true))
        }
        .padding(.top, 40)
    }

    private func shareText(code: String) -> String {
        "Join my poker group \"\(group.name)\" in Poker Night — enter this code: \(code)"
    }

    private func shareIfNeeded(force: Bool = false) async {
        guard force || group.joinCode == nil else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            _ = try await GroupSyncService.shared.shareGroup(group)
        } catch {
            #if DEBUG
            print("[Sync] share failed: \(error)")
            #endif
            errorMessage = friendlyMessage(for: error)
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        if error is SupabaseError {
            return "Sharing isn't configured on this build."
        }
        return "Couldn't reach the server. Check your connection and try again — a group that hasn't been shared in a while can also take a few extra seconds to wake up."
    }
}
