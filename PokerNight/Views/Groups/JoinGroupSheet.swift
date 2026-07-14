import SwiftUI
import SwiftData

/// Lets a viewer join a group by its share code. Pulls the group's current
/// snapshot into a local, read-only mirror and hands it back to the caller.
struct JoinGroupSheet: View {
    var onJoined: (GameGroup) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var code = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @FocusState private var codeIsFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CursorEndTextField(
                        placeholder: "Join code",
                        text: $code,
                        autocapitalization: .allCharacters,
                        autocorrection: .no
                    )
                    .focused($codeIsFocused)
                    .listRowBackground(AppTheme.surface)
                } header: {
                    SectionLabel("Enter the code you were given")
                } footer: {
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(AppTheme.accent)
                    }
                }
            }
            .appScreenBackground()
            .navigationTitle("Join a group")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { codeIsFocused = true }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Button("Join") { Task { await join() } }
                            .fontWeight(.semibold)
                            .disabled(trimmedCode.isEmpty)
                    }
                }
            }
        }
    }

    private var trimmedCode: String {
        code.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func join() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let group = try await GroupSyncService.shared.joinGroup(code: trimmedCode, context: modelContext)
            onJoined(group)
            dismiss()
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        if error is SupabaseError {
            return "Sharing isn't configured on this build."
        }
        return "Couldn't find a group for that code. If it hasn't been opened in a while, the server can take up to 30 seconds to wake up — try again in a moment."
    }
}
