import Foundation

public enum L10n {
    public static func t(_ th: String, _ en: String, lang: AppLanguage) -> String {
        lang == .th ? th : en
    }
}
