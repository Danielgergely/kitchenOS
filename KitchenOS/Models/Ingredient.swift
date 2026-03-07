//
//  Ingredient.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 2/16/26.
//
import Foundation
import SwiftData

enum Unit: String, Codable, CaseIterable {
    // solid
    case mg = "mg"
    case g = "g"
    case kg = "kg"
    
    // liquid
    case ml = "ml"
    case dl = "dl"
    case l = "l"
    
    // other
    case piece = "piece"
    case slice = "slice"
    case pack = "pack"
    
    // spoons
    case tsp = "tsp"
    case tbsp = "tbsp"
    
    // US
    case cup = "cup"
    case lbs = "lbs"
    case oz = "oz"
    
}

enum Category: String, Codable, CaseIterable {
    case general = "General"
    case diary = "Dairy"
    case produce = "Produce"
    case meat = "Meat"
    case saucesAndCondiments = "Sauces & Condiments"
    case wineBeerAndSpirits = "Wine, Beer & Spirits"
    case babyCare = "Baby Care"
    case bakery = "Bakery"
    case bakingItems = "Baking Items"
    case beverages = "Beverages"
    case breadsAndCerials = "Breads & Cereals"
    case cannedFoodsAndSoups = "Canned Foods & Soups"
    case coffeAndTea = "Coffe & Tea"
    case snacksAndCandy = "Snacks & Candy"
    case deli = "Deli"
    case frozenFoods = "Frozen Foods"
    case food = "Food"
    case oilsAndDressings = "Oils & Dressings"
    case pastaRiceAndBeans = "Pasta, Rice & Beans"
    case personalCareAndHealth = "Personal Care & Health"
    case petCare = "Pet Care"
    case seaFood = "Sea Food"
    case spicesAndSeasonings = "Spices & Seasonings"
    case other = "Other"
}

@Model
final class Ingredient {
    var id: UUID = UUID()
    var name: String
    var amount: Double
    var unit: Unit
    var category: Category
    
    var desc: String?
    var icon: String?
    @Attribute(.externalStorage) var image: Data?
    var calories: Int?
    
    @Relationship(inverse: \Recipe.ingredients)
    var recipe: Recipe?
    
    @Relationship(inverse: \Tag.recipes)
    var tags: [Tag] = []
    
    init(id: UUID, name: String, amount: Double = 1, unit: Unit = .piece, category: Category = .food, desc: String? = nil, icon: String? = nil, image: Data? = nil, calories: Int? = nil, tags: [Tag]) {
        self.id = id
        self.name = name
        self.amount = amount
        self.unit = unit
        self.category = category
        self.desc = desc
        self.icon = icon
        self.image = image
        self.calories = calories
        self.tags = tags
    }
}
