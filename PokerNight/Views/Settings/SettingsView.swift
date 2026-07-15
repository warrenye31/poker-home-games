import SwiftUI

struct SettingsView: View {
    @AppStorage("defaultBuyIn") private var defaultBuyIn: Double = 20
    @State private var defaultBuyInText = ""

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

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
                    MoneyFieldRow(label: "Default buy-in", placeholder: "Amount", text: $defaultBuyInText)
                        .onChange(of: defaultBuyInText) { _, newValue in
                            if let parsed = Double(newValue) { defaultBuyIn = parsed }
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
                    LabeledContent("Version", value: appVersion)
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
