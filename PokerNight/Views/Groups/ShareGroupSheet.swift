import SwiftUI
import UIKit

/// Admin-only sheet: publishes the group to Supabase (if not already shared)
/// and hands the organizer everything a friend needs to get in — the App Store
/// link and the join code, in the order they'll be used.
///
/// The code is the hero here, and it's a button: a code you can only read is a
/// code that gets retyped wrong into a text message. Everything that can be
/// copied, copies on tap and says so.
struct ShareGroupSheet: View {
    @Bindable var group: GameGroup

    @Environment(\.dismiss) private var dismiss
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var copied: CopyTarget?
    @State private var copyCount = 0

    /// What the last tap put on the pasteboard, so exactly one control shows
    /// the confirmation.
    private enum CopyTarget {
        case code, message, link
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if isWorking {
                        ProgressView("Publishing group\u{2026}")
                            .padding(.top, 60)
                    } else if let code = group.joinCode {
                        invite(code: code)
                    } else if let errorMessage {
                        errorCard(errorMessage)
                    }
                }
                .padding(20)
            }
            .appScreenBackground()
            .navigationTitle("Invite your friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sensoryFeedback(.success, trigger: copyCount)
            .task { await shareIfNeeded() }
        }
    }

    // MARK: - Invite

    private func invite(code: String) -> some View {
        VStack(spacing: 20) {
            codeCard(code)

            VStack(spacing: 10) {
                // One tap sends app link and code together, which is the whole
                // invite — the pieces below are for when someone already has the
                // app, or asks for just the code again.
                ShareLink(item: inviteMessage(code: code)) {
                    Label("Send invite", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.pill(prominent: true))

                Button {
                    copy(inviteMessage(code: code), as: .message)
                } label: {
                    Label(
                        copied == .message ? "Invite copied" : "Copy invite message",
                        systemImage: copied == .message ? "checkmark" : "doc.on.doc"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.pill(prominent: false))
            }

            stepsCard
            appLinkCard

            Text("Anyone with this code can view \(group.name)'s stats \u{2014} they can't edit players or sessions.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            syncFooter
        }
    }

    /// The join code, sized to be read across a room and tappable to copy.
    private func codeCard(_ code: String) -> some View {
        Button {
            copy(code, as: .code)
        } label: {
            VStack(spacing: 12) {
                SectionLabel("Join code")
                Text(code)
                    .font(.system(size: 38, weight: .heavy, design: .monospaced))
                    .tracking(6)
                    // Tracking pads the trailing edge of the last character too,
                    // which pulls the whole string visually left of centre.
                    .padding(.leading, 6)
                    .foregroundStyle(AppTheme.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                HStack(spacing: 6) {
                    Image(systemName: copied == .code ? "checkmark.circle.fill" : "doc.on.doc")
                    Text(copied == .code ? "Copied" : "Tap to copy")
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(copied == .code ? AppTheme.accent : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)
            .padding(.horizontal, 16)
            .background(
                AppTheme.accent.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        AppTheme.accent.opacity(0.55),
                        style: StrokeStyle(lineWidth: 2, dash: [7, 5])
                    )
            }
        }
        .buttonStyle(.plain)
        // Spelled out: VoiceOver reads a run of letters like "PQRS" as a word.
        .accessibilityLabel("Join code \(spelledOut(code)). Tap to copy.")
    }

    /// What the person on the other end actually has to do. Without this the
    /// code is a string with no instructions attached to it.
    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("How they join")
            step(1, "Install \(AppLinks.appName) from the App Store.")
            step(2, "On the Groups tab, tap \u{201C}Join a group\u{201D}.")
            step(3, "Enter the code above \u{2014} every game shows up on their phone from then on.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.accent)
                .frame(width: 22, height: 22)
                .background(AppTheme.accent.opacity(0.15), in: Circle())
            Text(text)
                .font(.footnote)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The App Store link on its own, for the times you're pasting into a chat
    /// by hand rather than using the share sheet.
    private var appLinkCard: some View {
        HStack(spacing: 12) {
            Link(destination: AppLinks.appStoreURL) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.down.app.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("App Store link")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(AppLinks.appStoreURL.absoluteString)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer(minLength: 0)
                }
            }

            Button {
                copy(AppLinks.appStoreURL.absoluteString, as: .link)
            } label: {
                Image(systemName: copied == .link ? "checkmark" : "doc.on.doc")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 40, height: 34)
                    .background(AppTheme.inputFill, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Copy App Store link")
        }
        .cardBackground()
    }

    private var syncFooter: some View {
        VStack(spacing: 10) {
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

    // MARK: - Text

    private func spelledOut(_ code: String) -> String {
        code.map { String($0) }.joined(separator: " ")
    }

    /// Everything needed to get in, in the order it's used: where to get the
    /// app, then the code. A bare code assumes the person already has the app,
    /// which for the friend you're inviting is exactly the wrong assumption.
    private func inviteMessage(code: String) -> String {
        """
        Join my poker group "\(group.name)" on \(AppLinks.appName).

        1. Get the app: \(AppLinks.appStoreURL.absoluteString)
        2. Tap "Join a group" on the Groups tab
        3. Enter this code: \(code)
        """
    }

    // MARK: - Actions

    private func copy(_ text: String, as target: CopyTarget) {
        UIPasteboard.general.string = text
        copyCount += 1
        withAnimation(.snappy(duration: 0.2)) { copied = target }
        // Reverts so the sheet doesn't sit on a stale "Copied" forever; the
        // generation check keeps an older timer from clearing a newer copy.
        let generation = copyCount
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if copyCount == generation {
                withAnimation(.snappy(duration: 0.2)) { copied = nil }
            }
        }
    }

    private func shareIfNeeded(force: Bool = false) async {
        // Backstop for the disabled toolbar button. Publishing without
        // admin_player_id would leave the host's own seat claimable by the first
        // viewer to open the group — see GameGroup.canShare.
        guard group.canShare else {
            errorMessage = "Pick which player is you before inviting people."
            return
        }
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
            errorMessage = SyncErrorMessage.text(for: error, action: .share)
        }
    }
}
