import SwiftUI

struct SettingsView: View {
    @AppStorage("defaultBuyIn") private var defaultBuyIn: Double = 20
    @State private var defaultBuyInText = ""

    private var currencyCode: Binding<String> {
        Binding(
            get: { CurrencySettings.shared.code },
            set: { CurrencySettings.shared.setCode($0) }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Default buy-in")
                        Spacer()
                        CursorEndTextField(
                            placeholder: "Amount",
                            text: $defaultBuyInText,
                            keyboardType: .decimalPad,
                            alignment: .trailing,
                            style: .money()
                        )
                        .frame(width: 90)
                        .onChange(of: defaultBuyInText) { _, newValue in
                            if let parsed = Double(newValue) { defaultBuyIn = parsed }
                        }
                    }
                    .listRowBackground(AppTheme.surface)
                    Picker("Currency", selection: currencyCode) {
                        Text("CAD ($)").tag("CAD")
                        Text("USD ($)").tag("USD")
                        Text("GBP (\u{00A3})").tag("GBP")
                        Text("EUR (\u{20AC})").tag("EUR")
                    }
                    .listRowBackground(AppTheme.surface)
                } header: {
                    SectionLabel("Defaults")
                }

                Section {
                    LabeledContent("Version", value: "1.0")
                        .listRowBackground(AppTheme.surface)
                } header: {
                    SectionLabel("About")
                }
            }
            .appScreenBackground()
            .navigationTitle("Settings")
            .onAppear {
                if defaultBuyInText.isEmpty {
                    defaultBuyInText = defaultBuyIn.truncatingRemainder(dividingBy: 1) == 0
                        ? String(Int(defaultBuyIn))
                        : String(defaultBuyIn)
                }
            }
        }
    }
}
