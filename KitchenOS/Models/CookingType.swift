//
//  CookingType.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/8/26.
//
import Foundation
import SwiftUI

enum CookingType: String, Codable, CaseIterable {
    case homeCooked = "Home Cooked Meal"
    case eatingOut = "Eating Out"
    case leftovers = "Leftovers"
    case takeOut = "Take Out"
    
    var icon: String {
        switch self {
        case .homeCooked: return "frying.pan.fill"
        case .eatingOut: return "fork.knife"
        case .leftovers: return "refrigerator.fill"
        case .takeOut: return "takeoutbag.and.cup.and.straw.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .homeCooked: return .green
        case .eatingOut: return .red
        case .leftovers: return .teal
        case .takeOut: return .orange
        }
    }
}
