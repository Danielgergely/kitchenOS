//
//  RecipePreview.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/21/26.
//
struct RecipePreview: Codable, Hashable {
    let title: String
    let timeMinutes: Int
    let category: String
    let imageUrl: String?
}
