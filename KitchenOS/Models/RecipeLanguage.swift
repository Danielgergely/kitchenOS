//
//  RecipeLanguage.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 6/9/26.
//
//  Global preference for the language recipes are extracted/translated into.
//  Stored in UserDefaults so the non-View AIService can read it directly, and
//  bound via @AppStorage("recipeLanguage") in Settings.
//

import Foundation

enum RecipeLanguage: String, CaseIterable, Identifiable {
    case automatic
    case english
    case german
    case french
    case italian
    case spanish
    case dutch
    case portuguese

    var id: String { rawValue }

    static let storageKey = "recipeLanguage"

    static var current: RecipeLanguage {
        let raw = UserDefaults.standard.string(forKey: storageKey) ?? RecipeLanguage.automatic.rawValue
        return RecipeLanguage(rawValue: raw) ?? .automatic
    }

    /// Label shown in Settings.
    var displayName: String {
        switch self {
        case .automatic:  return "Automatic (Device Language)"
        case .english:    return "English"
        case .german:     return "German"
        case .french:     return "French"
        case .italian:    return "Italian"
        case .spanish:    return "Spanish"
        case .dutch:      return "Dutch"
        case .portuguese: return "Portuguese"
        }
    }

    /// The English language name handed to the model (e.g. "German"). For
    /// `.automatic` this resolves to the device's current language.
    var resolvedLanguageName: String {
        switch self {
        case .automatic:
            let code = Locale.current.language.languageCode?.identifier ?? "en"
            return Locale(identifier: "en").localizedString(forLanguageCode: code) ?? "English"
        default:
            // displayName without any parenthetical is the language name.
            return displayName
        }
    }
}
