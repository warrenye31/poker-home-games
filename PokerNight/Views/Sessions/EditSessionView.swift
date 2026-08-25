import SwiftUI
import SwiftData

struct EditSessionView: View {
    @Bindable var session: Session

    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var location: String
    @State private var smallBlindText: String
    @State private var bigBlindText: String
    @State private var standardBuyInText: String
    @State private var usesBank: Bool
    @State private var bankPlayer: Player?

    init(session: Session) {
        self.session = session
        _date = State(initialValue: session.date)
        _location = State(initialValue: session.location ?? "")
        _smallBlindText = State(initialValue: session.smallBlind.map { "\($0)" } ?? "")
        _bigBlindText = State(initialValue: session.bigBlind.map { "\($0)" } ?? "")
        _standardBuyInText = State(initialValue: "\(session.standardBuyIn)")
        _usesBank = State(initialValue: session.usesBank)
        _bankPlayer = State(initialValue: session.bankPlayer)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .listRowBackground(AppTheme.surface)
                    CursorEndTextField(placeholder: "Location (optional)", text: $location)
                        .inputFieldStyle()
                        .listRowBackground(AppTheme.surface)
                } header: {
                    SectionLabel("Details")
                }

                Section {
                    BlindPresetRow(smallBlindText: $smallBlindText, bigBlindText: $bigBlindText)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(AppTheme.surface)
                    MoneyFieldRow(label: "Small blind", text: $smallBlindText)
                        .listRowBackground(AppTheme.surface)
                    MoneyFieldRow(label: "Big blind", text: $bigBlindText)
                        .listRowBackground(AppTheme.surface)
                    MoneyFieldRow(label: "Standard buy-in", placeholder: "Amount", text: $standardBuyInText)
                        .listRowBackground(AppTheme.surface)
                } header: {
                    SectionLabel("Stakes")
                }

                Section {
                    Toggle("Use a bank", isOn: $usesBank)
                        .listRowBackground(AppTheme.surface)
                    if usesBank {
                        Picker("Bank", selection: $bankPlayer) {
                            Text("Select a player").tag(Player?.none)
                            ForEach(participants) { player in
                                Text(player.name).tag(Optional(player))
                            }
                        }
                        .listRowBackground(AppTheme.surface)
                    }
                } header: {
                    SectionLabel("Bank")
                }
            }
            .appScreenBackground()
            .navigationTitle("Edit session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled((usesBank && bankPlayer == nil) || !(session.group?.canEdit ?? true))
                }
            }
        }
    }

    private var participants: [Player] {
        session.seatedEntries.compactMap(\.player)
    }

    private func save() {
        session.date = date
        let trimmedLocation = location.trimmingCharacters(in: .whitespaces)
        session.location = trimmedLocation.isEmpty ? nil : trimmedLocation
        session.smallBlind = Decimal(string: smallBlindText)
        session.bigBlind = Decimal(string: bigBlindText)
        session.standardBuyIn = Decimal(string: standardBuyInText) ?? session.standardBuyIn
        session.usesBank = usesBank
        session.bankPlayer = usesBank ? bankPlayer : nil
        if let group = session.group {
            GroupSyncService.shared.pushSnapshotIfShared(group)
        }
        dismiss()
    }
}
