//
//  TransferRecipeBook.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/1/26.
//
import SwiftUI
import SwiftData

struct TransferRecipeBook: Codable {
    let id: UUID
    let title: String
    let icon: String
    let imageData: Data?
}
