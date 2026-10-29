//
//  RuleBasedRecommender.swift
//  KitchenOS
//
//  Picks recipes from the library with plain scoring rules — the no-AI
//  fallback for meal suggestions, so they work on every device without a
//  server. It honours the same constraints the AI prompt spells out: allergies
//  and dislikes are excluded, upcoming meals are skipped, recent meals are
//  pushed down, and requested ingredients, favourites and the vibe push up.
//

import Foundation

enum RuleBasedRecommender {

    static func recommend(
        context: RecommendationContext,
        preferences: UserPreferences,
        upcomingMeals: [PlannedMeal],
        pastMeals: [PlannedMeal],
        availableRecipes: [Recipe],
        count: Int = 3
    ) -> [LibraryRecommendationResult] {
        let maxTime = context.timeOverride ?? preferences.maxPrepTimeMinutes ?? 60
        let upcoming = Set(upcomingMeals.map { $0.displayTitle.lowercased() })
        let recent = Set(pastMeals.map { $0.displayTitle.lowercased() })
        let avoided = (preferences.allergies + preferences.dislikedIngredients).map { $0.lowercased() }
        let requested = terms(in: context.includedIngredients, separators: ",")
        let vibe = terms(in: context.vibe, separators: " ,").filter { $0.count > 3 }

        let safe = availableRecipes.filter { recipe in
            !upcoming.contains(recipe.title.lowercased())
                && !avoided.contains { searchableText(of: recipe).contains($0) }
        }
        // Time is a preference, not a hard rule: if nothing fits, ignore it.
        let quickEnough = safe.filter { $0.prepTime.totalMinutes <= maxTime }
        let candidates = quickEnough.isEmpty ? safe : quickEnough

        let scored = candidates.map { recipe -> (recipe: Recipe, score: Double, reasons: [String]) in
            let text = searchableText(of: recipe)
            let tagNames: [String] = (recipe.tags ?? []).map { $0.name }
            var score = Double.random(in: 0..<1) // variety between equally good picks
            var reasons: [String] = []

            let hits = requested.filter { text.contains($0) }
            if !hits.isEmpty {
                score += 3 * Double(hits.count)
                reasons.append("Has \(hits.joined(separator: " and ")), as you asked")
            }
            if let tag = tagNames.first(where: { name in preferences.favoriteTags.contains { $0.caseInsensitiveCompare(name) == .orderedSame } }) {
                score += 2
                reasons.append("\(tag) is one of your favourite styles")
            }
            if let favourite = preferences.favoriteIngredients.first(where: { text.contains($0.lowercased()) }) {
                score += 1
                reasons.append("Uses \(favourite.lowercased()), a favourite of yours")
            }
            if vibe.contains(where: { text.contains($0) }) {
                score += 1
                reasons.append("Fits the \(context.vibe) mood")
            }
            if let rating = recipe.averageRating {
                score += rating / 5
            }
            if recent.contains(recipe.title.lowercased()) {
                score -= 3
            }
            return (recipe, score, reasons)
        }

        return scored
            .sorted { $0.score > $1.score }
            .prefix(count)
            .map { pick in
                let time = "Ready in \(pick.recipe.prepTime.totalMinutes) minutes"
                let reason = (pick.reasons.prefix(2) + [time]).joined(separator: ". ") + "."
                return LibraryRecommendationResult(recipeId: pick.recipe.id, reason: reason)
            }
    }

    private static func terms(in text: String, separators: String) -> [String] {
        text.lowercased()
            .split(whereSeparator: { separators.contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func searchableText(of recipe: Recipe) -> String {
        let ingredients: [String] = (recipe.ingredients ?? []).map { $0.name }
        let tags: [String] = (recipe.tags ?? []).map { $0.name }
        return ([recipe.title, recipe.summary] + ingredients + tags).joined(separator: " ").lowercased()
    }
}
