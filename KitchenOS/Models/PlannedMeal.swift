//
//  PlannedMeal.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 2/16/26.
//
import Foundation
import SwiftData

@Model
final class PlannedMeal {
    var type: MealType = MealType.dinner
    var guestCount: Int?
    var notes: String = ""
    var title: String?

    @Relationship(deleteRule: .nullify) var recipe: Recipe?

    var day: Day?

    var cookingType: CookingType? = CookingType.homeCooked

    var historicalRecipeName: String?
    var historicalTags: [String]?
    var ratingGiven: Int?

    // JSON snapshot of the recipe at assignment time — lets the other household member
    // display recipe details even if they don't own that recipe in their library
    var sharedRecipeData: Data?

    var displayTitle: String {
        if let recipeTitle = recipe?.title { return recipeTitle }
        if let customTitle = title, !customTitle.isEmpty { return customTitle }
        return type.rawValue
    }

    var isCompleted: Bool {
        return (day?.date ?? Date()) < Date()
    }
    
    init(type: MealType, day: Day? = nil, guestCount: Int? = nil, title: String? = nil, notes: String = "", recipe: Recipe? = nil, cookingType: CookingType = .homeCooked) {
        self.title = title
        self.type = type
        self.guestCount = guestCount
        self.notes = notes
        self.recipe = recipe
        self.day = day
        self.cookingType = cookingType
        
        if let currentRecipe = recipe {
            self.historicalRecipeName = currentRecipe.title
            self.historicalTags = (currentRecipe.tags ?? []).map { $0.name }
        } else {
            self.historicalRecipeName = title ?? type.rawValue
        }
    }
}
