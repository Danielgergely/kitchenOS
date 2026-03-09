//
//  UserPreferences.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/9/26.
//
import SwiftData
import Foundation

enum DietaryPreference: String, Codable, CaseIterable {
    case none = "None"
    case vegetarian = "Vegetarian"
    case vegan = "Vegan"
    case pescatarian = "Pescatarian"
    case keto = "Keto"
    case paleo = "Paleo"
}

enum SkillLevel: String, Codable, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
}

@Model
final class UserPreferences {
    
    // Explicit Preferences
    var cookingSkillLevel: SkillLevel = SkillLevel.intermediate
    var dietaryPreferences: DietaryPreference = DietaryPreference.none
    var allergies: [String] = [] // Wallnut, Gluten
    var dislikedIngredients: [String] = []
    var targetDailyCalories: Int? // 1500kcal
    var eatOutFrequency: Int? // 1-7 times a week
    var takeOutFrequency: Int? // 1-7 times a week
    var maxPrepTimeMinutes: Int? // 30 minutes
    var planLeftovers: Bool = false

    // Implicit preferences
    var favoriteTags: [String] = [] // Sweet, Side
    var favoriteIngredients: [String] = [] // Salad, Potato, Rice
    var foodTypeFrequencies: [String: Int] = [:] // ["Soup": 5, "Main Dish": 23]

    @Attribute(.unique) var id: String = "currentUser"

    init(
        cookingSkillLevel: SkillLevel = .intermediate,
        dietaryPreferences: DietaryPreference = .none,
        allergies: [String] = [],
        dislikedIngredients: [String] = [],
        targetDailyCalories: Int? = nil,
        eatOutFrequency: Int? = nil,
        takeOutFrequency: Int? = nil,
        maxPrepTimeMinutes: Int? = nil,
        planLeftovers: Bool = false,
        favoriteTags: [String] = [],
        favoriteIngredients: [String] = [],
        foodTypeFrequencies: [String: Int] = [:]
    ) {
        self.cookingSkillLevel = cookingSkillLevel
        self.dietaryPreferences = dietaryPreferences
        self.allergies = allergies
        self.dislikedIngredients = dislikedIngredients
        self.targetDailyCalories = targetDailyCalories
        self.eatOutFrequency = eatOutFrequency
        self.takeOutFrequency = takeOutFrequency
        self.maxPrepTimeMinutes = maxPrepTimeMinutes
        self.planLeftovers = planLeftovers
        self.favoriteTags = favoriteTags
        self.favoriteIngredients = favoriteIngredients
        self.foodTypeFrequencies = foodTypeFrequencies
    }
    
}
