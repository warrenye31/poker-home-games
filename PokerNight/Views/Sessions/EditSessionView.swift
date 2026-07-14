import SwiftUI
import SwiftData

struct EditSessionView: View {
    @Bindable var session: Session

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var date: Date
    @State private var location: String
    @State private var smallBlindText: String
    @State private var bigBlindText: String
    @State private var standardBuyInText: String
    @State private var usesBank: Bool
    @State private var bankPlayer: Player?

    init(session: Session) {
        self.session = session
        _name = State(initialValue: session.name)
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
                    TextField("Session name (optional)", text: $name)
                        .listRowBackground(AppTheme.surface)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .listRowBackground(AppTheme.surface)
                    TextField("Location (optional)", text: $location)
                        .listRowBackground(AppTheme.surface)
                } header: {
                    SectionLabel("Details")
                }

                Section {
                    HStack {
                        Text("Small blind")
                        Spacer()
                        TextField("Optional", text: $smallBlindText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(AppTheme.money())
                            .monospacedDigit()
                            .frame(width: 100)
                    }
                    .listRowBackground(AppTheme.surface)
                    HStack {
                        Text("Big blind")
                        Spacer()
                        TextField("Optional", text: $bigBlindText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(AppTheme.money())
                            .monospacedDigit()
                            .frame(width: 100)
                    }
                    .listRowBackground(AppTheme.surface)
                    HStack {
                        Text("Standard buy-in")
                        Spacer()
                        TextField("Amount", text: $standardBuyInText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(AppTheme.money())
                            .monospacedDigit()
                            .frame(width: 100)
                    }
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
                        .disabled(usesBank && bankPlayer == nil)
                }
            }
        }
    }

    private var participants: [Player] {
        session.entries.compactMap(\.player)
    }

    private func save() {
        session.name = name.trimmingCharacters(in: .whitespaces)
        session.date = date
        let trimmedLocation = location.trimmingCharacters(in: .whitespaces)
        session.location = trimmedLocation.isEmpty ? nil : trimmedLocation
        session.smallBlind = Decimal(string: smallBlindText)
        session.bigBlind = Decimal(string: bigBlindText)
        session.standardBuyIn = Decimal(string: standardBuyInText) ?? session.standardBuyIn
        session.usesBank = usesBank
        session.bankPlayer = usesBank ? bankPlayer : nil
        dismiss()
    }
}
