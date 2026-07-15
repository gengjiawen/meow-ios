import Foundation

/// The Home Screen icons the user can pick in Settings. `primary` is the
/// default meow icon; every other case must have a matching `.appiconset`
/// in Assets.xcassets and be listed in
/// `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` (project.yml).
enum AppIcon: String, CaseIterable, Identifiable {
    /// Default meow icon (`AppIcon.appiconset`).
    case primary = "AppIcon"
    /// Flat-style cat leaping over a brick wall (`AppIconLeap.appiconset`).
    case leap = "AppIconLeap"

    var id: String {
        rawValue
    }

    /// Argument for `UIApplication.setAlternateIconName(_:)` — `nil` selects
    /// the primary icon.
    var alternateIconName: String? {
        self == .primary ? nil : rawValue
    }

    /// Localizable.strings key for the display label in the Settings picker.
    var titleKey: String {
        switch self {
        case .primary: "settings.appIcon.primary"
        case .leap: "settings.appIcon.leap"
        }
    }

    /// Maps `UIApplication.alternateIconName` back to a case. Unknown names
    /// (an icon dropped in an app update) fall back to `.primary`.
    init(alternateIconName: String?) {
        self = alternateIconName.flatMap(AppIcon.init(rawValue:)) ?? .primary
    }
}
