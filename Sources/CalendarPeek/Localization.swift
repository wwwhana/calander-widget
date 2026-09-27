import Foundation

enum L10n {
    static func text(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: .module)
    }
}
