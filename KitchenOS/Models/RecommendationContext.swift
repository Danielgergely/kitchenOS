//
//  RecommendationContext.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/13/26.
//
import Foundation

struct RecommendationContext {
    var mealType: MealType
    var timeOverride: Int?
    var vibe: String = ""
    var includedIngredients: String = ""
}

struct LibraryRecommendationResult: Codable {
    let recipeId: UUID
    let reason: String
}
