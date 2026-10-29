//
//  OnDeviceImportTests.swift
//  KitchenOSTests
//
//  Tests for the free, on-device import path: rule-based parsing of recognized
//  text, Vision text recognition on a rendered recipe card, rule-based meal
//  suggestions, and — where the simulator has it — Apple's on-device model.
//

import Testing
import SwiftData
import UIKit
@testable import KitchenOS

@MainActor
struct OnDeviceImportTests {

    private let crumbleCard = [
        "Grandma's Apple Crumble",
        "Serves 4 · Prep 20 min · Bake 40 min",
        "Ingredients",
        "• 750 g apples, peeled and",
        "sliced",
        "• 150 g flour",
        "• 100g cold butter",
        "• 1 tsp cinnamon",
        "Method",
        "1. Heat the oven to 180 °C.",
        "2. Toss the apples with lemon juice and",
        "cinnamon, put in a baking dish.",
        "3. Bake for 40 minutes until golden.",
    ]

    // MARK: - RecipeTextParser

    @Test func parsesSectionedRecipe() {
        let recipe = RecipeTextParser.parse(lines: crumbleCard)

        #expect(recipe.title == "Grandma's Apple Crumble")
        #expect(recipe.prepTime == 20)
        #expect(recipe.cookTime == 40)

        let ingredients = recipe.ingredients ?? []
        #expect(ingredients.count == 4)
        #expect(ingredients[0].name == "apples, peeled and sliced")
        #expect(ingredients[0].amount == 750)
        #expect(ingredients[0].unit == "g")
        #expect(ingredients[2].amount == 100) // "100g" glued
        #expect(ingredients[2].unit == "g")
        #expect(ingredients[3].unit == "tsp")

        #expect(recipe.instructions == """
            Heat the oven to 180 °C.
            Toss the apples with lemon juice and cinnamon, put in a baking dish.
            Bake for 40 minutes until golden.
            """)
    }

    @Test func parsesGermanRecipe() {
        let recipe = RecipeTextParser.parse(lines: [
            "Rösti",
            "Zubereitungszeit: 1 Std 15 Min",
            "Zutaten",
            "800 g Kartoffeln",
            "2 EL Butter",
            "Zubereitung",
            "Kartoffeln reiben und salzen.",
            "In der Butter goldbraun braten.",
        ])

        #expect(recipe.title == "Rösti")
        #expect(recipe.prepTime == 75)
        #expect(recipe.ingredients?.map(\.unit) == ["g", "tbsp"])
        #expect(recipe.instructions == "Kartoffeln reiben und salzen.\nIn der Butter goldbraun braten.")
    }

    @Test func parsesRecipeWithoutHeaders() {
        let recipe = RecipeTextParser.parse(lines: [
            "Quick Tomato Soup",
            "Comforting and ready in no time.",
            "400 g tomatoes",
            "1 onion",
            "Fry the onion, add the tomatoes and simmer for ten minutes.",
            "Blend until smooth and season to taste.",
        ])

        #expect(recipe.title == "Quick Tomato Soup")
        #expect(recipe.summary == "Comforting and ready in no time.")
        #expect(recipe.ingredients?.count == 2)
        #expect(recipe.instructions?.components(separatedBy: "\n").count == 2)
    }

    // MARK: - TextRecognizer (Vision)

    @Test func readsRenderedRecipeCard() async throws {
        let image = render(lines: crumbleCard)
        let lines = try await TextRecognizer.lines(in: image)
        let recipe = RecipeTextParser.parse(lines: lines)

        #expect(recipe.title?.contains("Apple Crumble") == true)
        #expect((recipe.ingredients ?? []).contains { $0.name?.contains("flour") == true && $0.amount == 150 })
        #expect(recipe.instructions?.contains("Heat the oven") == true)
    }

    private func render(lines: [String]) -> UIImage {
        let text = lines.joined(separator: "\n")
        let size = CGSize(width: 1000, height: 1100)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            (text as NSString).draw(
                in: CGRect(x: 50, y: 50, width: 900, height: 1000),
                withAttributes: [.font: UIFont.systemFont(ofSize: 34), .foregroundColor: UIColor.black]
            )
        }
    }

    // MARK: - RuleBasedRecommender

    @Test func recommendsSafeFavouritesFirst() throws {
        let container = try ModelContainer(
            for: Recipe.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        func recipe(_ title: String, minutes: Int, ingredients: [String]) -> Recipe {
            let r = Recipe(
                title: title,
                prepTime: PreparationTime(prepTime: minutes),
                ingredients: ingredients.map { Ingredient(id: UUID(), name: $0, tags: []) }
            )
            context.insert(r)
            return r
        }
        let curry = recipe("Chicken Curry", minutes: 30, ingredients: ["chicken", "rice"])
        let satay = recipe("Peanut Satay", minutes: 25, ingredients: ["peanuts", "chicken"])
        let roast = recipe("Sunday Roast", minutes: 180, ingredients: ["beef"])
        let pasta = recipe("Pasta", minutes: 20, ingredients: ["pasta", "tomato"])

        let picks = RuleBasedRecommender.recommend(
            context: RecommendationContext(mealType: .dinner, includedIngredients: "chicken"),
            preferences: UserPreferences(allergies: ["peanut"], maxPrepTimeMinutes: 60),
            upcomingMeals: [],
            pastMeals: [],
            availableRecipes: [curry, satay, roast, pasta]
        )

        #expect(picks.first?.recipeId == curry.id)            // asked-for ingredient wins
        #expect(!picks.contains { $0.recipeId == satay.id })  // allergy excluded
        #expect(!picks.contains { $0.recipeId == roast.id })  // too slow
        #expect(picks.first?.reason.contains("chicken") == true)
    }

    // MARK: - Apple's on-device model

    @Test(.enabled(if: OnDeviceModel.isAvailable, "Apple Intelligence isn't available here"))
    func onDeviceModelExtractsRecipe() async throws {
        let recipe = try await OnDeviceModel.extractRecipe(
            fromText: crumbleCard.joined(separator: "\n"),
            availableTags: ["Vegetarian", "Quick"]
        )
        #expect(recipe.title?.contains("Crumble") == true)
        #expect((recipe.ingredients ?? []).count >= 4)
        #expect((recipe.ingredients ?? []).contains { $0.amount == 750 && $0.unit == "g" })
    }
}
