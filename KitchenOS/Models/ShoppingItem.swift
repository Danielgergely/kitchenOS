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
    var name: String = ""
    var amount: Double = 1.0
    var unit: Unit = Unit.piece
    var isChecked: Bool = false
    var createdAt: Date = Date()
    var reminderId: String? = nil

    init(name: String, amount: Double, unit: Unit) {
        self.name = name
        self.amount = amount
        self.unit = unit
    }
}
