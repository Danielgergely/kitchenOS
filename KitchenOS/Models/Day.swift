//
//  Day.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 2/16/26.
//
import Foundation
import SwiftData

@Model
final class Day {
    @Attribute(.unique) var date: Date
    var note: String?
    
    @Relationship(deleteRule: .cascade, inverse: \PlannedMeal.day)
    var plannedMeals: [PlannedMeal] = []
    
    init(date: Date, note: String? = nil) {
        self.date = date
        self.note = note
    }
    
    func meal(for type: MealType) -> PlannedMeal? {
        return plannedMeals.first { $0.type == type }
    }
}
