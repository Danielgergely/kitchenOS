//
//  RecipeTransfer.swift
//  KitchenOS
//
//  The single place that converts between the SwiftData models and the Codable
//  transfer objects. This mapping used to be copy-pasted in five places (export,
//  shared-plan snapshot, import, opening a shared recipe, saving one to the
//  library), which is how the variants drifted apart.
//
//  Import direction takes a `resolveTag` closure so callers decide whether tags
//  should be looked up / inserted into a context (import) or dropped (transient
//  previews), without this file needing a ModelContext.
//

import Foundation

// MARK: - Model → Transfer

extension TransferTag {
    init(_ tag: Tag) {
        self.init(name: tag.name, icon: tag.icon, colorRawValue: tag.color.rawValue)
    }
}

extension TransferIngredient {
    init(_ ingredient: Ingredient) {
        self.init(
            name: ingredient.name,
            amount: ingredient.amount,
            unitRawValue: ingredient.unit.rawValue,
            categoryRawValue: ingredient.category.rawValue,
            desc: ingredient.desc,
            icon: ingredient.icon,
            imageData: ingredient.image,
            calories: ingredient.calories,
            tags: (ingredient.tags ?? []).map { TransferTag($0) }
        )
    }
}

extension TransferRecipe {
    init(_ recipe: Recipe) {
        self.init(
            id: recipe.id,
            title: recipe.title,
            summary: recipe.summary,
            instructions: recipe.instructions,
            imageData: recipe.image,
            typeRawValue: recipe.type.rawValue,
            prepTime: recipe.prepTime.prepTime,
            cookTime: recipe.prepTime.cookingTime,
            ingredients: (recipe.ingredients ?? []).map { TransferIngredient($0) },
            tags: (recipe.tags ?? []).map { TransferTag($0) },
            bookId: recipe.book?.id
        )
    }
}

extension TransferRecipeBook {
    init(_ book: RecipeBook) {
        self.init(id: book.id, title: book.title, icon: book.icon, imageData: book.image)
    }
}

// MARK: - Transfer → Model

/// Turns a transferred tag into a `Tag`. Import passes a closure that reuses or
/// inserts tags in a ModelContext; previews pass `nil` to drop tags entirely.
typealias TagResolver = (TransferTag) -> Tag

extension TransferIngredient {
    func makeIngredient(resolveTag: TagResolver? = nil) -> Ingredient {
        Ingredient(
            id: UUID(),
            name: name,
            amount: amount,
            unit: Unit(rawValue: unitRawValue) ?? .piece,
            category: Category(rawValue: categoryRawValue) ?? .food,
            desc: desc,
            icon: icon,
            image: imageData,
            calories: calories,
            tags: resolveTag.map { resolver in tags.map(resolver) } ?? []
        )
    }
}

extension TransferRecipe {
    /// Builds a `Recipe` from this snapshot. The result is *not* inserted into any
    /// context — callers insert it (library copy / import) or use it transiently
    /// (read-only preview of someone else's shared meal).
    ///
    /// `sourceRecipeId` always records where the recipe came from, so re-importing
    /// or re-saving the same share doesn't create duplicates.
    func makeRecipe(resolveTag: TagResolver? = nil) -> Recipe {
        let recipe = Recipe(
            title: title,
            summary: summary,
            instructions: instructions,
            image: imageData,
            type: FoodType(rawValue: typeRawValue) ?? .mainDish,
            prepTime: PreparationTime(prepTime: prepTime, cookingTime: cookTime),
            ingredients: ingredients.map { $0.makeIngredient(resolveTag: resolveTag) },
            tags: resolveTag.map { resolver in tags.map(resolver) } ?? []
        )
        recipe.sourceRecipeId = id
        return recipe
    }

    /// Decodes a snapshot produced by `DataExchangeService.snapshotRecipe`.
    static func decode(from data: Data?) -> TransferRecipe? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(TransferRecipe.self, from: data)
    }
}
