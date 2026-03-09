//
//  ProfilingEngine.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/9/26.
//
import Foundation
import SwiftData

class ProfilingEngine {
    
    /// Analyzes the last 30 days of meals to learn the user's implicit preferences.
    @MainActor
    static func updateLearnedPreferences(context: ModelContext) {
        // 1. Fetch the user profile (or exit if none exists)
        let descriptor = FetchDescriptor<UserPreferences>()
        guard let profile = try? context.fetch(descriptor).first else { return }
        
        // 2. Fetch Days from the last 30 days
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let daysDescriptor = FetchDescriptor<Day>(
            predicate: #Predicate { $0.date >= thirtyDaysAgo }
        )
        
        guard let recentDays = try? context.fetch(daysDescriptor) else { return }
        let recentMeals = recentDays.flatMap { $0.plannedMeals }
        
        if recentMeals.isEmpty { return }
        
        // 3. Trackers
        var tagCounts: [String: Int] = [:]
        var ingredientCounts: [String: Int] = [:]
        var foodTypeCounts: [String: Int] = [:]
        
        var eatingOutCount = 0
        
        // 4. Crunch the numbers
        for meal in recentMeals {
            if meal.cookingType == .eatingOut {
                eatingOutCount += 1
                continue
            }
            
            guard let recipe = meal.recipe else { continue }
            
            // Tally Food Types
            foodTypeCounts[recipe.type.rawValue, default: 0] += 1
            
            // Tally Tags
            for tag in recipe.tags {
                tagCounts[tag.name, default: 0] += 1
            }
            
            // Tally Ingredients
            for ingredient in recipe.ingredients {
                // Normalize ingredient names (e.g., "Tomato" and "tomatoes" -> "tomato")
                let normalized = ingredient.name.lowercased().trimmingCharacters(in: .whitespaces)
                ingredientCounts[normalized, default: 0] += 1
            }
        }
        
        // 5. Update Profile
        // Top 5 Tags
        profile.favoriteTags = tagCounts.sorted { $0.value > $1.value }
            .prefix(5).map { $0.key }
        
        // Top 10 Ingredients
        profile.favoriteIngredients = ingredientCounts.sorted { $0.value > $1.value }
            .prefix(10).map { $0.key.capitalized }
        
        // Food Type Frequencies
        profile.foodTypeFrequencies = foodTypeCounts
        
        // Estimate weekly eating out frequency based on the 4-week (30 days) period
        profile.eatOutFrequency = Int(round(Double(eatingOutCount) / 4.0))
        
        // Save the context
        try? context.save()
        print("🧠 Profiling Engine updated Taste Profile successfully.")
    }
}
