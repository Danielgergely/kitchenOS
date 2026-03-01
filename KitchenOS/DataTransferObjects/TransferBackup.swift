//
//  TransferBackup.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/1/26.
//
import SwiftUI
import SwiftData

struct TransferBackup: Codable {
    let books: [TransferRecipeBook]
    let recipes: [TransferRecipe]
}
