import SwiftUI

struct SettingsView: View {
    @AppStorage("defaultBuyIn") private var defaultBuyIn: Double = 20
    @AppStorage("currencyCode") private var currencyCode: String = "USD"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Default buy-in")
                        Spacer()
                        TextField("Amount", value: $defaultBuyIn, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(AppTheme.money())
                            .monospacedDigit()
                            .frame(width: 90)
                    }
                    .listRowBackground(AppTheme.surface)
                    Picker("Currency", selection: $currencyCode) {
                        Text("USD ($)").tag("USD")
                        Text("CAD ($)").tag("CAD")
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
        }
    }
}
