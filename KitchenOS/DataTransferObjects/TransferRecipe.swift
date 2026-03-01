//
//  TransferRecipe.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/1/26.
//
import SwiftUI
import SwiftData

struct TransferRecipe: Codable {
    let title: String
    let summary: String
    let instructions: String
    let imageData: Data?
    let typeRawValue: String
    let prepTime: Int
    let cookTime: Int
    let ingredients: [TransferIngredient]
    let tags: [TransferTag]
    let bookId: UUID?
}
