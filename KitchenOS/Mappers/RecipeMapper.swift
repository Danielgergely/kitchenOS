//
//  RecipeMapper.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/7/26.
//
import SwiftData
import SwiftUI


class RecipeMapper {
    @Query(sort: \Tag.name) private var allTags: [Tag]

    func extractedRecipeToRecipe(_ extracted: ExtractedRecipe) -> Recipe {
        
        var type: FoodType = .mainDish
        var tags: [Tag] = []
        var ingredients: [Ingredient] = []
        
        // Extracted food type
        if let typeString = extracted.type, let parsedType = FoodType(rawValue: typeString) {
            type = parsedType
        }
        
        // Extracted tags
        if let extractedTags = extracted.tags {
            let matchedTags = allTags.filter { extractedTags.contains($0.name) }
            tags = matchedTags
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
        
        return Recipe(
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
