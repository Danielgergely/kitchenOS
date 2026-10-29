//
//  OnDeviceModel.swift
//  KitchenOS
//
//  Recipe extraction with Apple's on-device language model (Foundation
//  Models): free, offline and private, but only on devices that support Apple
//  Intelligence, with it turned on. The model reads text, not photos, so photos
//  go through TextRecognizer first.
//
//  The model's context window is small (a few thousand tokens), so input text is
//  capped; a recipe photo or a trimmed web page fits comfortably.
//

import Foundation
import FoundationModels

enum OnDeviceModel {

    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    /// Why the model can't be used, for Settings; nil when it's available.
    static var unavailableReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return "Not supported on this device"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Apple Intelligence is turned off"
        case .unavailable(.modelNotReady):
            return "Model is still downloading"
        case .unavailable:
            return "Unavailable"
        }
    }

    /// Leaves room in the context window for the instructions and the answer.
    private static let maxInputCharacters = 6_000

    static func extractRecipe(fromText text: String, availableTags: [String]) async throws -> ExtractedRecipe {
        let language = RecipeLanguage.current.resolvedLanguageName
        let tagList = availableTags.isEmpty ? "none" : availableTags.joined(separator: ", ")
        let session = LanguageModelSession(instructions: """
            You extract recipes from text that was read from a photo or a web page.
            Copy amounts and units faithfully; never invent ingredients or steps.
            Write every field in \(language), translating if the source is in another language.
            For tags, use only these, or none: \(tagList).
            """)

        let response = try await session.respond(
            to: "Extract the recipe from this text:\n\n" + String(text.prefix(maxInputCharacters)),
            generating: GeneratedRecipe.self
        )
        return response.content.extractedRecipe
    }
}

// MARK: - Generated types

@Generable
struct GeneratedRecipe {
    @Guide(description: "The recipe's name")
    var title: String

    @Guide(description: "A short, appetizing 1-2 sentence description")
    var summary: String

    @Guide(description: "The method, one entry per step, without step numbers")
    var steps: [String]

    @Guide(description: "Preparation time in minutes, 0 if not stated")
    var prepTime: Int

    @Guide(description: "Cooking or baking time in minutes, 0 if not stated")
    var cookTime: Int

    @Guide(description: "The kind of dish", .anyOf(FoodType.allCases.map(\.rawValue)))
    var type: String

    @Guide(description: "Matching tags from the allowed list, or empty")
    var tags: [String]

    var ingredients: [GeneratedIngredient]

    var extractedRecipe: ExtractedRecipe {
        ExtractedRecipe(
            title: title,
            summary: summary,
            instructions: steps.joined(separator: "\n"),
            prepTime: prepTime,
            cookTime: cookTime,
            type: type,
            tags: tags,
            ingredients: ingredients.map {
                ExtractedIngredient(name: $0.name, amount: $0.amount, unit: $0.unit)
            },
            imageUrl: nil
        )
    }
}

@Generable
struct GeneratedIngredient {
    @Guide(description: "The ingredient, without amount or unit, e.g. \"brown sugar\"")
    var name: String

    @Guide(description: "The quantity; 1 if none is given")
    var amount: Double

    @Guide(.anyOf(Unit.allCases.map(\.rawValue)))
    var unit: String
}
