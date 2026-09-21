//
//  IngredientCatalog.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 6/9/26.
//
//  Phase 3 of "smart ingredients": a bundled (not stored) catalog keyed by the
//  canonical key from IngredientNormalizer. It supplies two things:
//   • density (g/ml) — lets mass and volume of the same ingredient combine
//     (e.g. "1 cup flour" + "200 g flour"), and
//   • a shopping category — so extracted ingredients land in a sensible aisle.
//  Still zero-migration: this is static data, no new CloudKit record type.
//

import Foundation

struct CatalogEntry {
    let densityGramsPerML: Double?   // nil when mass↔volume conversion isn't meaningful
    let category: Category
}

enum IngredientCatalog {

    static func entry(forKey key: String) -> CatalogEntry? { entries[key] }
    static func density(forKey key: String) -> Double? { entries[key]?.densityGramsPerML }
    static func category(forKey key: String) -> Category? { entries[key]?.category }

    /// canonical key → density + category. Keys match IngredientNormalizer's output.
    private static let entries: [String: CatalogEntry] = [
        "flour":     CatalogEntry(densityGramsPerML: 0.53, category: .bakingItems),
        "sugar":     CatalogEntry(densityGramsPerML: 0.85, category: .bakingItems),
        "salt":      CatalogEntry(densityGramsPerML: 1.22, category: .spicesAndSeasonings),
        "pepper":    CatalogEntry(densityGramsPerML: nil,  category: .spicesAndSeasonings),
        "butter":    CatalogEntry(densityGramsPerML: 0.96, category: .diary),
        "milk":      CatalogEntry(densityGramsPerML: 1.03, category: .diary),
        "egg":       CatalogEntry(densityGramsPerML: nil,  category: .diary),
        "oil":       CatalogEntry(densityGramsPerML: 0.92, category: .oilsAndDressings),
        "olive oil": CatalogEntry(densityGramsPerML: 0.92, category: .oilsAndDressings),
        "water":     CatalogEntry(densityGramsPerML: 1.00, category: .beverages),
        "onion":     CatalogEntry(densityGramsPerML: nil,  category: .produce),
        "garlic":    CatalogEntry(densityGramsPerML: nil,  category: .produce),
        "tomato":    CatalogEntry(densityGramsPerML: nil,  category: .produce),
        "rice":      CatalogEntry(densityGramsPerML: 0.85, category: .pastaRiceAndBeans),
        "pasta":     CatalogEntry(densityGramsPerML: nil,  category: .pastaRiceAndBeans),
        "cheese":    CatalogEntry(densityGramsPerML: nil,  category: .diary),
        "chicken":   CatalogEntry(densityGramsPerML: nil,  category: .meat),
        "beef":      CatalogEntry(densityGramsPerML: nil,  category: .meat),
        "potato":    CatalogEntry(densityGramsPerML: nil,  category: .produce),
        "carrot":    CatalogEntry(densityGramsPerML: nil,  category: .produce)
    ]
}
