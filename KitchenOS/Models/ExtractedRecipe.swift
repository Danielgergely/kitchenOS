//
//  ExtractedRecipe.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/7/26.
//
struct ExtractedRecipe: Codable {
    let title: String?
    let summary: String?
    let instructions: String?
    let prepTime: Int?
    let cookTime: Int?
    let type: String?
    let tags: [String]?
    let ingredients: [ExtractedIngredient]?
    let imageUrl: String?
}
