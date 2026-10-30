import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var loc: Localizer

    var body: some View {
        Form {
            Picker(loc.s.language, selection: $loc.language) {
                ForEach(AppLanguage.allCases) { Text($0.nativeName).tag($0) }
            }
            .pickerStyle(.radioGroup)
            Text(loc.s.languageNote).font(.caption).foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 380)
        .navigationTitle(loc.s.settings)
    }
}
