//
//  TransferIngredient.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/1/26.
//
import SwiftUI
import SwiftData

struct TransferIngredient: Codable {
    let name: String
    let amount: Double
    let unitRawValue: String
    let categoryRawValue: String
    let desc: String?
    let icon: String?
    let imageData: Data?
    let calories: Int?
    let tags: [TransferTag]
}
