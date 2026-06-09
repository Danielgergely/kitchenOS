//
//  RecipeJSONLDExtractor.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 6/8/26.
//
//  Most recipe websites embed machine-readable schema.org "Recipe" data as
//  JSON-LD (it's what powers Google's rich recipe cards). Parsing that directly
//  is free, instant, works on every device, and needs no LLM — so we try it
//  first and only fall back to the AI extractor when a page lacks it.
//
//  Spec: https://schema.org/Recipe
//

import Foundation

enum RecipeJSONLDExtractor {

    /// Returns a populated ExtractedRecipe if the HTML contains usable schema.org
    /// Recipe JSON-LD, otherwise nil (caller should fall back to the LLM).
    static func extract(fromHTML html: String) -> ExtractedRecipe? {
        for block in jsonLDBlocks(in: html) {
            let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let data = trimmed.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data),
                  let node = findRecipeNode(in: json) else { continue }
            if let recipe = buildRecipe(from: node) { return recipe }
        }
        return nil
    }

    // MARK: - Locating the Recipe node

    private static func findRecipeNode(in json: Any) -> [String: Any]? {
        if let dict = json as? [String: Any] {
            if isRecipeType(dict["@type"]) { return dict }
            // schema.org pages often wrap everything in an @graph array.
            if let graph = dict["@graph"], let found = findRecipeNode(in: graph) { return found }
        } else if let array = json as? [Any] {
            for element in array {
                if let found = findRecipeNode(in: element) { return found }
            }
        }
        return nil
    }

    private static func isRecipeType(_ type: Any?) -> Bool {
        if let s = type as? String { return s.caseInsensitiveCompare("Recipe") == .orderedSame }
        if let array = type as? [Any] {
            return array.contains { ($0 as? String)?.caseInsensitiveCompare("Recipe") == .orderedSame }
        }
        return false
    }

    // MARK: - Building the recipe

    private static func buildRecipe(from node: [String: Any]) -> ExtractedRecipe? {
        let title = (node["name"] as? String).map(cleanText)
        let summary = (node["description"] as? String).map(cleanText)
        let instructions = instructionsText(from: node["recipeInstructions"])

        var prepTime = minutes(fromISO: node["prepTime"] as? String)
        var cookTime = minutes(fromISO: node["cookTime"] as? String)
        // Fall back to totalTime if the page only lists a combined duration.
        if prepTime == nil && cookTime == nil {
            cookTime = minutes(fromISO: node["totalTime"] as? String)
        }
        _ = prepTime  // (kept explicit for readability of the prep/cook split)

        let ingredients = ingredientStrings(from: node["recipeIngredient"]).map(parseIngredient)
        let image = imageURL(from: node["image"])

        // Require a title plus at least ingredients or instructions to be worth using.
        guard title != nil, (!ingredients.isEmpty || instructions != nil) else { return nil }

        return ExtractedRecipe(
            title: title,
            summary: summary,
            instructions: instructions,
            prepTime: prepTime,
            cookTime: cookTime,
            type: nil,                                  // schema categories don't map cleanly; let user pick
            tags: nil,
            ingredients: ingredients.isEmpty ? nil : ingredients,
            imageUrl: image
        )
    }

    // MARK: - Field parsers

    /// recipeInstructions may be a string, an array of strings, an array of
    /// HowToStep objects ({text}), or HowToSection objects containing nested steps.
    private static func instructionsText(from any: Any?) -> String? {
        guard let any else { return nil }
        if let s = any as? String {
            let c = cleanText(s)
            return c.isEmpty ? nil : c
        }
        if let array = any as? [Any] {
            var steps: [String] = []
            for element in array {
                if let s = element as? String {
                    steps.append(s)
                } else if let dict = element as? [String: Any] {
                    if isType(dict["@type"], "HowToSection"),
                       let nested = instructionsText(from: dict["itemListElement"]) {
                        steps.append(nested)
                    } else if let text = dict["text"] as? String {
                        steps.append(text)
                    } else if let name = dict["name"] as? String {
                        steps.append(name)
                    }
                }
            }
            let joined = steps.map(cleanText).filter { !$0.isEmpty }.joined(separator: "\n")
            return joined.isEmpty ? nil : joined
        }
        return nil
    }

    /// recipeIngredient is usually [String]; tolerate a single string too.
    private static func ingredientStrings(from any: Any?) -> [String] {
        if let array = any as? [Any] { return array.compactMap { $0 as? String } }
        if let s = any as? String { return [s] }
        return []
    }

    /// image may be a URL string, an ImageObject ({url}), or arrays of either.
    private static func imageURL(from any: Any?) -> String? {
        if let s = any as? String { return s }
        if let dict = any as? [String: Any] { return dict["url"] as? String }
        if let array = any as? [Any] {
            for element in array {
                if let s = element as? String { return s }
                if let dict = element as? [String: Any], let u = dict["url"] as? String { return u }
            }
        }
        return nil
    }

    // MARK: - Ingredient string → name / amount / unit

    /// Lightweight parse of "1 1/2 cups all-purpose flour" → (1.5, cup, "all-purpose flour").
    private static func parseIngredient(_ raw: String) -> ExtractedIngredient {
        let text = cleanText(raw)
        var tokens = text.split(separator: " ").map(String.init)
        guard !tokens.isEmpty else { return ExtractedIngredient(name: text, amount: nil, unit: nil) }

        var amount: Double?
        if let first = quantity(from: tokens[0]) {
            amount = first
            tokens.removeFirst()
            // Mixed number, e.g. "1 1/2".
            if let next = tokens.first, let frac = fraction(from: next), first == first.rounded(.down) {
                amount = first + frac
                tokens.removeFirst()
            }
        }

        var unit: String?
        if let candidate = tokens.first, let matched = matchUnit(candidate) {
            unit = matched
            tokens.removeFirst()
        }

        let name = tokens.joined(separator: " ")
        return ExtractedIngredient(name: name.isEmpty ? text : name, amount: amount, unit: unit)
    }

    private static let unicodeFractions: [Character: Double] = [
        "½": 0.5, "⅓": 1.0/3.0, "⅔": 2.0/3.0, "¼": 0.25, "¾": 0.75,
        "⅕": 0.2, "⅖": 0.4, "⅗": 0.6, "⅘": 0.8, "⅙": 1.0/6.0,
        "⅛": 0.125, "⅜": 0.375, "⅝": 0.625, "⅞": 0.875
    ]

    /// Parses an integer, decimal, "1/2", or unicode fraction (incl. "1½").
    private static func quantity(from token: String) -> Double? {
        if let frac = fraction(from: token) { return frac }
        // "1½"
        if let last = token.last, let frac = unicodeFractions[last] {
            let intPart = String(token.dropLast())
            if let whole = Double(intPart) { return whole + frac }
            if intPart.isEmpty { return frac }
        }
        return Double(token.replacingOccurrences(of: ",", with: "."))
    }

    private static func fraction(from token: String) -> Double? {
        if token.count == 1, let only = token.first, let f = unicodeFractions[only] { return f }
        guard token.contains("/") else { return nil }
        let parts = token.split(separator: "/")
        guard parts.count == 2, let n = Double(parts[0]), let d = Double(parts[1]), d != 0 else { return nil }
        return n / d
    }

    private static let unitAliases: [String: String] = [
        "cup": "cup", "cups": "cup",
        "tbsp": "tbsp", "tbsps": "tbsp", "tablespoon": "tbsp", "tablespoons": "tbsp",
        "tsp": "tsp", "tsps": "tsp", "teaspoon": "tsp", "teaspoons": "tsp",
        "g": "g", "gram": "g", "grams": "g",
        "kg": "kg", "kilogram": "kg", "kilograms": "kg",
        "mg": "mg",
        "ml": "ml", "milliliter": "ml", "milliliters": "ml", "millilitre": "ml", "millilitres": "ml",
        "dl": "dl",
        "l": "l", "liter": "l", "liters": "l", "litre": "l", "litres": "l",
        "oz": "oz", "ounce": "oz", "ounces": "oz",
        "lb": "lbs", "lbs": "lbs", "pound": "lbs", "pounds": "lbs",
        "slice": "slice", "slices": "slice",
        "pack": "pack", "packs": "pack", "package": "pack", "packages": "pack",
        "piece": "piece", "pieces": "piece", "pcs": "piece", "pc": "piece"
    ]

    private static func matchUnit(_ token: String) -> String? {
        let key = token.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".,"))
        return unitAliases[key]
    }

    // MARK: - ISO 8601 duration → minutes

    /// Parses durations like "PT1H30M", "PT45M", "P0DT0H30M" into total minutes.
    private static func minutes(fromISO iso: String?) -> Int? {
        guard let iso, iso.hasPrefix("P") else { return nil }

        let datePart: String
        let timePart: String
        if let tRange = iso.range(of: "T") {
            datePart = String(iso[..<tRange.lowerBound])
            timePart = String(iso[tRange.upperBound...])
        } else {
            datePart = iso
            timePart = ""
        }

        let days = firstInt(in: datePart, suffix: "D") ?? 0
        let hours = firstInt(in: timePart, suffix: "H") ?? 0
        let mins = firstInt(in: timePart, suffix: "M") ?? 0

        let total = days * 1440 + hours * 60 + mins
        return total > 0 ? total : nil
    }

    private static func firstInt(in string: String, suffix: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: "(\\d+)\(suffix)") else { return nil }
        let ns = string as NSString
        guard let match = regex.firstMatch(in: string, range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges > 1 else { return nil }
        return Int(ns.substring(with: match.range(at: 1)))
    }

    // MARK: - Helpers

    private static func isType(_ type: Any?, _ name: String) -> Bool {
        if let s = type as? String { return s.caseInsensitiveCompare(name) == .orderedSame }
        if let array = type as? [Any] {
            return array.contains { ($0 as? String)?.caseInsensitiveCompare(name) == .orderedSame }
        }
        return false
    }

    /// Strips HTML tags, decodes a few common entities, and collapses whitespace.
    private static func cleanText(_ raw: String) -> String {
        var s = raw.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let entities = ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
                        "&#39;": "'", "&apos;": "'", "&nbsp;": " "]
        for (entity, char) in entities {
            s = s.replacingOccurrences(of: entity, with: char)
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func jsonLDBlocks(in html: String) -> [String] {
        let pattern = "<script[^>]*type=[\"']application/ld\\+json[\"'][^>]*>(.*?)</script>"
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return [] }
        let ns = html as NSString
        return regex.matches(in: html, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            return ns.substring(with: match.range(at: 1))
        }
    }
}
