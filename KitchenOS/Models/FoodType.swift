//
//  FoodType.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 2/16/26.
//
// FoodType.swift
import Foundation

enum FoodType: String, Codable, CaseIterable {
    case starter = "Starter"
    case soup = "Soup"
    case salad = "Salad"
    case mainDish = "Main Dish"
    case desert = "Desert"
    case snack = "Snack"
    case side = "Side"
    case other = "Other"

    struct Info {
        let name: String
        let icon: String
    }

    var info: Info {
        switch self {
        case .starter:   return .init(name: rawValue, icon: "cheese")
        case .soup:      return .init(name: rawValue, icon: "noodles")
        case .salad:     return .init(name: rawValue, icon: "vegetable.lettuce")
        case .mainDish:  return .init(name: rawValue, icon: "main.dish")
        case .desert:    return .init(name: rawValue, icon: "birthday.cake")
        case .snack:     return .init(name: rawValue, icon: "cookies")
        case .side:      return .init(name: rawValue, icon: "french.fries")
        case .other:     return .init(name: rawValue, icon: "paella")
        }
    }
}
