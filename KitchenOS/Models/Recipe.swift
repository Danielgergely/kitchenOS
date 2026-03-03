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
    // Attributes
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
    
    // Relationships
    @Relationship(inverse: \Tag.recipes)
    var tags: [Tag] = []
    
    @Relationship(inverse: \PlannedMeal.recipe)
    var plannedMeals: [PlannedMeal] = []
    
    // Calcualted statistical values
    var timesCooked: Int {
            plannedMeals.filter { $0.isCompleted }.count
        }
    
    var averageRating: Double? {
        let ratedMeals = plannedMeals.filter { $0.isCompleted && $0.ratingGiven != nil }
        guard !ratedMeals.isEmpty else { return nil }
        
        let totalScore = ratedMeals.compactMap { $0.ratingGiven }.reduce(0, +)
        return Double(totalScore) / Double(ratedMeals.count)
    }
    
    var lastCookedDate: Date? {
        let completedMeals = plannedMeals.filter { $0.isCompleted }
        // Sorts the meals by date, newest first, and grabs the top one
        return completedMeals.compactMap { $0.day?.date }.max()
    }
    
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
