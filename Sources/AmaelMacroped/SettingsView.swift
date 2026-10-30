import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var loc: Localizer
    @AppStorage("appearance") private var appearance: AppAppearance = .auto

    var body: some View {
        VStack(alignment: .leading, spacing: AppStyle.Spacing.small) {
            Text(loc.s.settings).font(AppStyle.Typography.pageTitle).foregroundStyle(AppColors.textPrimary)

            SectionHeader(loc.s.language).padding(.top, AppStyle.Spacing.xSmall)
            Card {
                CardRow(title: loc.s.language, caption: loc.s.languageNote) {
                    Dropdown(value: loc.language.nativeName, minWidth: 170) {
                        ForEach(AppLanguage.allCases) { lang in
                            Button(lang.nativeName) { loc.language = lang }
                        }
                    }
                }
            }

            SectionHeader(loc.s.appearance).padding(.top, AppStyle.Spacing.xSmall)
            Card {
                VStack(alignment: .leading, spacing: AppStyle.Spacing.small) {
                    CardRow(title: loc.s.appearance, caption: loc.s.appearanceCaption) { EmptyView() }
                    SegmentedControl(options: AppAppearance.allCases, selection: $appearance) { $0.title(loc.s) }
                }
            }
        }
        .padding(AppStyle.Spacing.large)
        .frame(width: 460)
        .background(AppColors.surfaceBase)
        .tint(AppColors.actionPrimary)
        .preferredColorScheme(appearance.colorScheme)
    }
}
