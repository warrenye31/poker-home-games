import SwiftUI
import SwiftData

struct GroupFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @FocusState private var nameIsFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CursorEndTextField(placeholder: "Group name", text: $name)
                        .focused($nameIsFocused)
                        .listRowBackground(AppTheme.surface)
                }
            }
            .appScreenBackground()
            .navigationTitle("New group")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { nameIsFocused = true }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let group = GameGroup(name: trimmedName)
                        modelContext.insert(group)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }
}
