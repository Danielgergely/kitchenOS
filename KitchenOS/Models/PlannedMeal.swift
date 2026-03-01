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
    var type: MealType
    var guestCount: Int?
    var isEatingOut: Bool = false
    var notes: String = ""
    var title: String?
    
    var recipe: Recipe?
    
    var day: Day?
    
    var displayTitle: String {
        if isEatingOut { return "Eating Out" }
        if let recipeTitle = recipe?.title { return recipeTitle }
        return title ?? "Untitled"
    }
    
    init(type: MealType, guestCount: Int? = nil, isEatingOut: Bool = false, title: String? = nil, notes: String = "", recipe: Recipe? = nil, day: Day? = nil) {
        self.title = title
        self.type = type
        self.guestCount = guestCount
        self.isEatingOut = isEatingOut
        self.notes = notes
        self.recipe = recipe
        self.day = day
    }
}
