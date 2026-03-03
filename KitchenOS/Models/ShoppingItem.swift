//
//  ShoppingItem.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/2/26.
//
import Foundation
import SwiftData

@Model
class ShoppingItem {
    var name: String
    var amount: Double
    var unit: Unit
    var isChecked: Bool = false
    var createdAt: Date = Date()

    init(name: String, amount: Double, unit: Unit) {
        self.name = name
        self.amount = amount
        self.unit = unit
    }
}
