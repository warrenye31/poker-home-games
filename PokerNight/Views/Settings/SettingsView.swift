import SwiftUI

struct SettingsView: View {
    @AppStorage("defaultBuyIn") private var defaultBuyIn: Double = 20
    @AppStorage("currencyCode") private var currencyCode: String = "USD"

    var body: some View {
        NavigationStack {
            Form {
                Section("Defaults") {
                    HStack {
                        Text("Default buy-in")
                        Spacer()
                        TextField("Amount", value: $defaultBuyIn, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    Picker("Currency", selection: $currencyCode) {
                        Text("USD ($)").tag("USD")
                        Text("CAD ($)").tag("CAD")
                        Text("GBP (\u{00A3})").tag("GBP")
                        Text("EUR (\u{20AC})").tag("EUR")
                    }
                }

                Section {
                    LabeledContent("Version", value: "1.0")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
