//
//  StoreRecipeBook.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/21/26.
//

import Foundation

struct StoreRecipeBook: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let description: String?
    let author: String?
    let price: Double
    let storekitId: String?
    let coverImageUrl: String?
    let jsonDownloadUrl: String?
    let isPublished: Bool
    let recipeCount: Int?
    let previewRecipes: [RecipePreview]?
    
    // This tells Swift how to map the snake_case database columns to camelCase Swift properties
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case author
        case price
        case storekitId = "storekit_id"
        case coverImageUrl = "cover_image_url"
        case jsonDownloadUrl = "json_download_url"
        case isPublished = "is_published"
        case recipeCount = "recipe_count"
        case previewRecipes = "preview_recipes"
    }
}
