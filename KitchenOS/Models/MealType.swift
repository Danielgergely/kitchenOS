//
//  MealType.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 2/16/26.
//
import Foundation

enum MealType: String, Codable, CaseIterable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snack"
}
