//
//  Language.swift
//  shove95
//
//  The languages the interface OFFERS. Not the languages it speaks yet.
//
//  Founder direction 2026-08-16: build the option first, translate later. So
//  this is a real list, a real stored preference and a real picker — and
//  nothing reads the choice to pick strings with. `isTranslated` is what will
//  turn true a language at a time; until then the picker is honest about it
//  rather than pretending.
//
//  Endonyms, not English names: a person looking for their own language scans
//  for the word they call it, and "Deutsch" is easier to spot in a long list
//  than "German". The English name rides along so the SEARCH matches either —
//  typing "german" or "deutsch" both find it.
//

import Foundation

struct Language: Identifiable, Equatable, Sendable {
    /// BCP-47. This is what gets stored, and what a future
    /// `Bundle.preferredLocalizations` lookup will key on.
    let code: String
    /// What speakers call it.
    let endonym: String
    /// What English calls it — search only, never displayed on its own.
    let english: String
    /// True once the app actually ships strings for it.
    var isTranslated: Bool = false

    var id: String { code }

    /// The one language the app is written in. Everything else is an
    /// intention.
    static let english_ = Language(code: "en", endonym: "English",
                                   english: "English", isTranslated: true)

    /// Matches on the endonym, the English name, the code — and the name this
    /// language has in whatever language the app is CURRENTLY showing.
    ///
    /// That last one is the point (founder direction 2026-08-17). Someone
    /// running the app in German looks for "Französisch", not "Français" and
    /// not "French"; someone who has just switched to French looks for
    /// "français". Neither of them should have to guess which spelling the
    /// list was written in.
    ///
    /// The display name comes from the system, not from a table here: iOS
    /// already knows every language's name in every language, and a hand-kept
    /// list of thirty squared is a promise nobody can keep.
    func matches(_ query: String, displayedIn locale: Locale) -> Bool {
        let q = query.folded
        guard !q.isEmpty else { return true }
        if endonym.folded.contains(q) || english.folded.contains(q) || code.folded.contains(q) {
            return true
        }
        guard let localised = locale.localizedString(forIdentifier: code) else { return false }
        return localised.folded.contains(q)
    }

    /// Ordered as the picker shows them: English first because it is the one
    /// that works, then alphabetical by endonym.
    static let all: [Language] = [english_] + [
        Language(code: "ar", endonym: "العربية", english: "Arabic"),
        Language(code: "zh-Hans", endonym: "简体中文", english: "Chinese Simplified"),
        Language(code: "zh-Hant", endonym: "繁體中文", english: "Chinese Traditional"),
        Language(code: "cs", endonym: "Čeština", english: "Czech"),
        Language(code: "da", endonym: "Dansk", english: "Danish"),
        Language(code: "nl", endonym: "Nederlands", english: "Dutch"),
        Language(code: "fi", endonym: "Suomi", english: "Finnish"),
        Language(code: "fr", endonym: "Français", english: "French"),
        Language(code: "de", endonym: "Deutsch", english: "German"),
        Language(code: "el", endonym: "Ελληνικά", english: "Greek"),
        Language(code: "he", endonym: "עברית", english: "Hebrew"),
        Language(code: "hi", endonym: "हिन्दी", english: "Hindi"),
        Language(code: "hu", endonym: "Magyar", english: "Hungarian"),
        Language(code: "id", endonym: "Bahasa Indonesia", english: "Indonesian"),
        Language(code: "it", endonym: "Italiano", english: "Italian"),
        Language(code: "ja", endonym: "日本語", english: "Japanese"),
        Language(code: "ko", endonym: "한국어", english: "Korean"),
        Language(code: "nb", endonym: "Norsk bokmål", english: "Norwegian"),
        Language(code: "pl", endonym: "Polski", english: "Polish"),
        Language(code: "pt-BR", endonym: "Português (Brasil)", english: "Portuguese Brazil"),
        Language(code: "pt-PT", endonym: "Português (Portugal)", english: "Portuguese Portugal"),
        Language(code: "ro", endonym: "Română", english: "Romanian"),
        Language(code: "ru", endonym: "Русский", english: "Russian"),
        Language(code: "sk", endonym: "Slovenčina", english: "Slovak"),
        Language(code: "es", endonym: "Español", english: "Spanish"),
        Language(code: "sv", endonym: "Svenska", english: "Swedish"),
        Language(code: "th", endonym: "ไทย", english: "Thai"),
        Language(code: "tr", endonym: "Türkçe", english: "Turkish"),
        Language(code: "uk", endonym: "Українська", english: "Ukrainian"),
        Language(code: "vi", endonym: "Tiếng Việt", english: "Vietnamese"),
    ].sorted { $0.endonym.localizedCaseInsensitiveCompare($1.endonym) == .orderedAscending }

    static func named(_ code: String) -> Language {
        all.first { $0.code == code } ?? english_
    }
}

private extension String {
    /// Case- and diacritic-insensitive, so a search box does not demand
    /// accents the keyboard is not currently offering.
    var folded: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
