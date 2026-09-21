//
//  IngredientNormalizer.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 6/9/26.
//
//  Phase 2 of "smart ingredients": resolve different spellings, descriptors, and
//  languages of the same ingredient to one canonical key — WITHOUT a schema change.
//  The key is computed on the fly from the name string, so there's no new CloudKit
//  record type and no migration. The shopping-list aggregator matches on this key,
//  so "flour", "all-purpose flour", and "Mehl" all combine into one line.
//
//  A stored, user-editable catalog (browsable UI, custom aliases) would be Phase 3.
//

import Foundation

enum IngredientNormalizer {

    /// A stable key used only for *matching* (never shown to the user).
    /// Two ingredient names that produce the same key are treated as the same thing.
    static func canonicalKey(_ raw: String) -> String {
        let cleaned = strippedOfDescriptors(clean(raw))
        let candidate = cleaned.isEmpty ? clean(raw) : cleaned

        // Exact synonym / translation hit.
        if let canon = synonyms[candidate] { return canon }

        // Try the singular form (English plurals).
        let singular = singularized(candidate)
        if let canon = synonyms[singular] { return canon }

        return singular
    }

    /// The preferred human label for a known ingredient, or a tidied version of the
    /// user's text when it's not in the table. Currently used sparingly — the shopping
    /// list keeps whatever the user first typed — but available for future UI.
    static func displayName(_ raw: String) -> String {
        let key = canonicalKey(raw)
        if let pretty = displayNames[key] { return pretty }
        return clean(raw).capitalized
    }

    // MARK: - Text processing

    private static func clean(_ raw: String) -> String {
        let lowered = raw.lowercased()
        let allowed = lowered.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) || scalar == " " || scalar == "-" {
                return Character(scalar)
            }
            return " "
        }
        return String(allowed)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func strippedOfDescriptors(_ cleaned: String) -> String {
        cleaned
            .split(separator: " ")
            .map(String.init)
            .filter { !descriptors.contains($0) }
            .joined(separator: " ")
    }

    /// Conservative English singularization — only when safe, to avoid wrong merges.
    private static func singularized(_ word: String) -> String {
        // Only singularize the last token of a multi-word name.
        var tokens = word.split(separator: " ").map(String.init)
        guard let last = tokens.last, last.count > 3 else { return word }

        let lower = last
        let singular: String
        if lower.hasSuffix("ies") {
            singular = String(lower.dropLast(3)) + "y"      // berries -> berry
        } else if lower.hasSuffix("ss") || lower.hasSuffix("us") || lower.hasSuffix("is") {
            singular = lower                                  // molasses, hummus, etc. unchanged
        } else if lower.hasSuffix("es") && (lower.hasSuffix("oes") || lower.hasSuffix("ches") || lower.hasSuffix("shes")) {
            singular = String(lower.dropLast(2))             // tomatoes -> tomato
        } else if lower.hasSuffix("s") {
            singular = String(lower.dropLast())              // eggs -> egg
        } else {
            singular = lower
        }
        tokens[tokens.count - 1] = singular
        return tokens.joined(separator: " ")
    }

    // MARK: - Data

    /// Cooking descriptors stripped before matching (EN / DE / FR).
    private static let descriptors: Set<String> = [
        // English
        "fresh", "freshly", "dried", "ground", "chopped", "diced", "minced", "sliced",
        "large", "small", "medium", "ripe", "raw", "cooked", "whole", "fine", "finely",
        "coarse", "coarsely", "organic", "boneless", "skinless", "peeled", "grated",
        "shredded", "crushed", "softened", "melted", "cold", "warm", "hot", "extra",
        // German
        "frisch", "frische", "getrocknet", "gemahlen", "gehackt", "gewürfelt", "groß",
        "große", "klein", "kleine", "reif", "roh", "gekocht", "ganze", "fein",
        // French
        "frais", "fraîche", "haché", "hachée", "émincé", "moulu", "cuit", "cru", "gros"
    ]

    /// normalized-name → canonical key. Conservative: only true synonyms and
    /// translations, never specificity-reducing maps (e.g. "bread flour" stays separate).
    private static let synonyms: [String: String] = [
        // Flour
        "flour": "flour", "plain flour": "flour", "all purpose flour": "flour",
        "all-purpose flour": "flour", "mehl": "flour", "farine": "flour",
        // Sugar
        "sugar": "sugar", "white sugar": "sugar", "caster sugar": "sugar",
        "granulated sugar": "sugar", "zucker": "sugar", "sucre": "sugar",
        // Salt
        "salt": "salt", "table salt": "salt", "sea salt": "salt", "salz": "salt", "sel": "salt",
        // Pepper
        "pepper": "pepper", "black pepper": "pepper", "pfeffer": "pepper", "poivre": "pepper",
        // Butter
        "butter": "butter", "unsalted butter": "butter", "beurre": "butter",
        // Milk
        "milk": "milk", "whole milk": "milk", "milch": "milk", "lait": "milk",
        // Eggs
        "egg": "egg", "eggs": "egg", "ei": "egg", "eier": "egg", "oeuf": "egg", "œuf": "egg",
        // Oil
        "oil": "oil", "olive oil": "olive oil", "vegetable oil": "oil",
        "öl": "oil", "olivenöl": "olive oil", "huile": "oil", "huile d olive": "olive oil",
        // Water
        "water": "water", "wasser": "water", "eau": "water",
        // Onion / Garlic
        "onion": "onion", "onions": "onion", "zwiebel": "onion", "oignon": "onion",
        "garlic": "garlic", "garlic clove": "garlic", "knoblauch": "garlic", "ail": "garlic",
        // Tomato
        "tomato": "tomato", "tomatoes": "tomato", "tomate": "tomato", "tomaten": "tomato",
        // Common staples
        "rice": "rice", "reis": "rice", "riz": "rice",
        "pasta": "pasta", "nudeln": "pasta", "pâtes": "pasta",
        "cheese": "cheese", "käse": "cheese", "fromage": "cheese",
        "chicken": "chicken", "huhn": "chicken", "hähnchen": "chicken", "poulet": "chicken",
        "beef": "beef", "rindfleisch": "beef", "boeuf": "beef",
        "potato": "potato", "potatoes": "potato", "kartoffel": "potato",
        "kartoffeln": "potato", "pomme de terre": "potato",
        "carrot": "carrot", "carrots": "carrot", "karotte": "carrot",
        "möhre": "carrot", "carotte": "carrot"
    ]

    /// canonical key → preferred display label.
    private static let displayNames: [String: String] = [
        "flour": "Flour", "sugar": "Sugar", "salt": "Salt", "pepper": "Pepper",
        "butter": "Butter", "milk": "Milk", "egg": "Egg", "oil": "Oil",
        "olive oil": "Olive Oil", "water": "Water", "onion": "Onion", "garlic": "Garlic",
        "tomato": "Tomato", "rice": "Rice", "pasta": "Pasta", "cheese": "Cheese",
        "chicken": "Chicken", "beef": "Beef", "potato": "Potato", "carrot": "Carrot"
    ]
}
