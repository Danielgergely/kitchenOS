//
//  Recipe.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 2/16/26.
//
import Foundation
import SwiftData

@Model
final class Recipe {
    var id: UUID = UUID()
    var title: String
    var summary: String
    var instructions: String
    
    @Attribute(.externalStorage) var image: Data?
    var webLink: URL?
    var type: FoodType

    var prepTime: PreparationTime
    var ingredients: [Ingredient]
    
    var book: RecipeBook?
    
    @Relationship(inverse: \Tag.recipes)
    var tags: [Tag] = []
    
    @Relationship(deleteRule: .cascade, inverse: \PlannedMeal.recipe)
    var plannedMeals: [PlannedMeal] = []
    
    init(title: String, summary: String = "", instructions: String = "", image: Data? = nil, type: FoodType = .mainDish, prepTime: PreparationTime = PreparationTime(), ingredients: [Ingredient] = [], tags: [Tag] = []) {
            self.title = title
            self.summary = summary
            self.instructions = instructions
            self.image = image
            self.type = type
            self.prepTime = prepTime
            self.ingredients = ingredients
            self.tags = tags
        }
    
}
