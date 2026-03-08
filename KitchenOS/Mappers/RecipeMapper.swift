//
//  RecipeMapper.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/7/26.
//
import SwiftData
import SwiftUI

struct DraftRecipe {
    let title: String
    let summary: String
    let instructions: String
    let image: Image?
    let type: FoodType
    let prepTime: PreparationTime
    let ingredients: [Ingredient]
    let tags: [Tag]
}

struct RecipeMapper {

    static func extractedRecipeToRecipe(_ extracted: ExtractedRecipe, availableTags allTags: [Tag]) -> DraftRecipe {
        
        var type: FoodType = .mainDish
        var tags: [Tag] = []
        var ingredients: [Ingredient] = []
        
        // Extracted food type
        if let typeString = extracted.type, let parsedType = FoodType(rawValue: typeString) {
            type = parsedType
        }
        
        // Extracted tags
        if let extractedTags = extracted.tags {
            let lowercasedExtracted = extractedTags.map { $0.lowercased() }
            tags = allTags.filter { lowercasedExtracted.contains($0.name.lowercased()) }
        }
        
        // Extracted Ingredients
        if let aiIngredients = extracted.ingredients {
            ingredients = aiIngredients.compactMap { extIng in
                let name = extIng.name ?? "Unknown Ingredient"
                let amount = extIng.amount ?? 1.0
                let unitString = extIng.unit ?? "piece"
                
                let matchedUnit = Unit(rawValue: unitString.lowercased()) ?? .piece
                
                return Ingredient(
                    id: UUID(),
                    name: name,
                    amount: amount,
                    unit: matchedUnit,
                    category: .food,
                    tags: []
                )
            }
        }
        
        let prepTime = PreparationTime(prepTime: extracted.prepTime ?? 0, cookingTime: extracted.cookTime ?? 0)
        
        return DraftRecipe(
            title: extracted.title ?? "Scanned Recipe",
            summary: extracted.summary ?? "",
            instructions: extracted.instructions ?? "",
            image: nil,
            type: type,
            prepTime: prepTime,
            ingredients: ingredients,
            tags: tags
        )
    }
}
