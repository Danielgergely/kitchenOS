//
//  PlannedMeal.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 2/16/26.
//
import Foundation
import SwiftData

enum CookingType: String, Codable, CaseIterable {
    case homeCooked = "Home Cooked Meal"
    case eatingOut = "Eating Out"
    case leftovers = "Leftovers"
    case takeOut = "Take Out"
}

@Model
final class PlannedMeal {
    var type: MealType
    var guestCount: Int?
    var notes: String = ""
    var title: String?
    
    @Relationship(deleteRule: .nullify) var recipe: Recipe?
    
    var day: Day?
    
    var cookingType: CookingType? = CookingType.homeCooked
    
    var historicalRecipeName: String?
    var historicalTags: [String]?
    var ratingGiven: Int?
    
    var displayTitle: String {
        if let recipeTitle = recipe?.title { return recipeTitle }
        if let customTitle = title, !customTitle.isEmpty { return customTitle }
        return type.rawValue
    }
    
    var isCompleted: Bool {
        guard let mealDate = day?.date else { return false }
        return mealDate < Date()
    }
    
    init(type: MealType, guestCount: Int? = nil, title: String? = nil, notes: String = "", recipe: Recipe? = nil, day: Day? = nil, cookingType: CookingType = .homeCooked) {
        self.title = title
        self.type = type
        self.guestCount = guestCount
        self.notes = notes
        self.recipe = recipe
        self.day = day
        self.cookingType = cookingType
        
        if let currentRecipe = recipe {
            self.historicalRecipeName = currentRecipe.title
            self.historicalTags = currentRecipe.tags.map { $0.name }
        } else {
            self.historicalRecipeName = title ?? type.rawValue
        }
    }
}
