//
//  RecipeTextParser.swift
//  KitchenOS
//
//  Turns the lines of text read from a recipe photo into an ExtractedRecipe
//  with plain rules — no model at all. It's the import path that works on
//  every device, offline: weaker than an AI on unusual layouts, but printed
//  recipes with "Ingredients" / "Method" sections come through well, and the
//  result lands in the editor for the user to correct anyway.
//
//  Recognizes section headers in English, German, French, Italian, Spanish,
//  Dutch and Portuguese. It can't translate: the recipe keeps the photo's language.
//

import Foundation

nonisolated enum RecipeTextParser {

    static func parse(lines rawLines: [String]) -> ExtractedRecipe {
        let lines = rawLines.map(Line.init).filter { !$0.text.isEmpty }

        let ingredientHeader = lines.firstIndex { isHeader($0.text, ingredientHeaders) }
        let methodHeader = lines.firstIndex { isHeader($0.text, methodHeaders) }

        var intro: [Line] = []
        var ingredientLines: [Line] = []
        var methodLines: [Line] = []

        switch (ingredientHeader, methodHeader) {
        case let (i?, m?) where m > i:
            intro = Array(lines[..<i])
            ingredientLines = Array(lines[(i + 1)..<m])
            methodLines = Array(lines[(m + 1)...])
        case let (i?, m?):
            // Method printed before the ingredients.
            intro = Array(lines[..<m])
            methodLines = Array(lines[(m + 1)..<i])
            ingredientLines = Array(lines[(i + 1)...])
        case let (i?, nil):
            intro = Array(lines[..<i])
            for line in lines[(i + 1)...] {
                let stillInList = methodLines.isEmpty && (isContinuation(line) || line.text.hasSuffix(":"))
                if ingredientLines.isEmpty || looksLikeIngredient(line) || stillInList {
                    ingredientLines.append(line)
                } else {
                    methodLines.append(line)
                }
            }
        case let (nil, m?):
            for line in lines[..<m] {
                if looksLikeIngredient(line) { ingredientLines.append(line) } else { intro.append(line) }
            }
            methodLines = Array(lines[(m + 1)...])
        case (nil, nil):
            // No headers: classify line by line.
            for line in lines {
                if looksLikeIngredient(line) {
                    ingredientLines.append(line)
                } else if looksLikeStep(line) || !methodLines.isEmpty {
                    methodLines.append(line)
                } else {
                    intro.append(line)
                }
            }
        }

        let descriptive = intro.filter { !isMetadata($0.text) }
        let title = descriptive.first?.text ?? lines.first?.text
        let summary = descriptive.dropFirst().map(\.text).joined(separator: " ")
        let allText = lines.map(\.text).joined(separator: "\n")

        return ExtractedRecipe(
            title: title,
            summary: summary.isEmpty ? nil : String(summary.prefix(300)),
            instructions: steps(from: methodLines).joined(separator: "\n"),
            prepTime: minutes(in: allText, labels: prepLabels),
            cookTime: minutes(in: allText, labels: cookLabels),
            type: nil,
            tags: nil,
            ingredients: ingredients(from: ingredientLines).map(RecipeJSONLDExtractor.parseIngredient),
            imageUrl: nil
        )
    }

    // MARK: - Lines

    private struct Line {
        let text: String
        /// Started with a bullet — a list item, never a continuation of the line above.
        let bulleted: Bool

        init(_ raw: String) {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            let stripped = trimmed.replacingOccurrences(
                of: "^[•·∙●○▪■◦*\\-–—]+\\s*", with: "", options: .regularExpression
            )
            text = stripped.trimmingCharacters(in: .whitespaces)
            bulleted = stripped.count != trimmed.count
        }
    }

    private static let ingredientHeaders = [
        "ingredients", "ingredient", "you will need", "you'll need",
        "zutaten", "ingrédients", "ingredienti", "ingredientes", "ingrediënten",
    ]

    private static let methodHeaders = [
        "method", "instructions", "directions", "preparation", "steps", "how to make it", "how to make",
        "zubereitung", "anleitung", "préparation", "preparazione", "procedimento",
        "preparación", "elaboración", "bereiding", "bereidingswijze", "modo de preparo",
    ]

    private static func isHeader(_ text: String, _ keywords: [String]) -> Bool {
        let normalized = text.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: " :.-"))
        return keywords.contains { normalized == $0 || (normalized.hasPrefix($0 + " ") && normalized.count < 30) }
    }

    private static func looksLikeIngredient(_ line: Line) -> Bool {
        guard line.text.count <= 70 else { return false }
        return startsWithQuantity(line.text) || (line.bulleted && line.text.count <= 60)
    }

    private static func looksLikeStep(_ line: Line) -> Bool {
        stepNumber(in: line.text) != nil || line.text.count >= 50
    }

    private static func startsWithQuantity(_ text: String) -> Bool {
        text.range(of: "^([0-9]|[½⅓⅔¼¾⅛])", options: .regularExpression) != nil
    }

    /// OCR breaks long lines; a line starting in lower case continues the one above.
    private static func isContinuation(_ line: Line) -> Bool {
        !line.bulleted && (line.text.first?.isLowercase ?? false)
    }

    /// "Serves 4 · Prep 20 min" and the like — not a title or a description.
    private static func isMetadata(_ text: String) -> Bool {
        let lower = text.lowercased()
        let markers = ["serves", "servings", "portion", "personen", "yield", "makes",
                       "min", "hour", "std", "kcal", "calories"]
        return text.contains(where: \.isNumber) && markers.contains { lower.contains($0) }
    }

    // MARK: - Ingredients

    private static func ingredients(from lines: [Line]) -> [String] {
        var result: [String] = []
        for line in lines {
            // "For the dough:" style sub-headings carry no quantity.
            if line.text.hasSuffix(":") && !startsWithQuantity(line.text) { continue }
            if isContinuation(line), let last = result.popLast() {
                result.append(last + " " + line.text)
            } else {
                result.append(line.text)
            }
        }
        return result
    }

    // MARK: - Steps

    /// Rebuilds steps from wrapped OCR lines. Numbered steps ("1." / "2)" / "Step 3")
    /// start where their number is; otherwise a step ends at a sentence's end.
    private static func steps(from lines: [Line]) -> [String] {
        let numbered = lines.contains { stepNumber(in: $0.text) != nil }
        var steps: [String] = []
        var current = ""

        func flush() {
            let step = current.trimmingCharacters(in: .whitespaces)
            if !step.isEmpty { steps.append(step) }
            current = ""
        }

        for line in lines {
            if numbered {
                if let number = stepNumber(in: line.text) {
                    flush()
                    current = String(line.text[number.upperBound...])
                } else if line.bulleted {
                    flush()
                    current = line.text
                } else {
                    current += " " + line.text
                }
            } else {
                if line.bulleted { flush() }
                current += " " + line.text
                if let last = line.text.last, ".!?".contains(last) { flush() }
            }
        }
        flush()
        return steps
    }

    private static func stepNumber(in text: String) -> Range<String.Index>? {
        text.range(
            of: "^((step|schritt|étape|passo|paso|stap)\\s*)?\\d{1,2}\\s*[.):]\\s*|^(step|schritt)\\s*\\d{1,2}\\s+",
            options: [.regularExpression, .caseInsensitive]
        )
    }

    // MARK: - Times

    private static let prepLabels = [
        "prep time", "preparation time", "prep", "vorbereitungszeit", "vorbereitung",
        "zubereitungszeit", "temps de préparation", "tempo di preparazione",
        "tiempo de preparación", "voorbereidingstijd",
    ]

    private static let cookLabels = [
        "cook time", "cooking time", "cook", "bake", "baking time", "backzeit", "backen",
        "kochzeit", "garzeit", "temps de cuisson", "cuisson", "tempo di cottura", "cottura",
        "tiempo de cocción", "cocción", "kooktijd", "baktijd",
    ]

    /// The first "<label> … 1 h 20 min" in the text, in minutes.
    private static func minutes(in text: String, labels: [String]) -> Int? {
        let lower = text.lowercased()
        for label in labels {
            let pattern = "\(NSRegularExpression.escapedPattern(for: label))[^0-9\\n]{0,12}"
                + "(?:(\\d+)\\s*(?:h|hr|hrs|hours?|std|stunden?)\\s*)?(?:(\\d+)\\s*(?:min|minutes?|minuten))?"
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let ns = lower as NSString
            for match in regex.matches(in: lower, range: NSRange(location: 0, length: ns.length)) {
                let hours = match.range(at: 1).location != NSNotFound ? Int(ns.substring(with: match.range(at: 1))) ?? 0 : 0
                let mins = match.range(at: 2).location != NSNotFound ? Int(ns.substring(with: match.range(at: 2))) ?? 0 : 0
                if hours + mins > 0 { return hours * 60 + mins }
            }
        }
        return nil
    }
}
