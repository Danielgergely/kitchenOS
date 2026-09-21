//
//  UnitConverter.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 6/9/26.
//
//  Phase 1 of "smart ingredients": unit math only, no schema change.
//  Converts amounts to a base unit per dimension so quantities can be summed,
//  then renders the total back in a sensible unit within the same family.
//

import Foundation
import SwiftData

/// The physical quantity a unit measures. Units only combine within one dimension.
enum Measure {
    case mass      // base: gram
    case volume    // base: millilitre
    case count     // base: piece (not interconvertible — a slice ≠ a pack)
}

extension Unit {
    var dimension: Measure {
        switch self {
        case .mg, .g, .kg, .lbs, .oz:        return .mass
        case .ml, .dl, .l, .tsp, .tbsp, .cup: return .volume
        case .piece, .slice, .pack:           return .count
        }
    }

    /// Factor to convert one of this unit into the dimension's base unit.
    var baseFactor: Double {
        switch self {
        // mass → grams
        case .mg:  return 0.001
        case .g:   return 1
        case .kg:  return 1000
        case .oz:  return 28.3495
        case .lbs: return 453.592
        // volume → millilitres
        case .ml:  return 1
        case .dl:  return 100
        case .l:   return 1000
        case .tsp: return 4.92892
        case .tbsp: return 14.7868
        case .cup: return 240
        // count → pieces
        case .piece, .slice, .pack: return 1
        }
    }
}

enum UnitConverter {

    static func toBase(_ amount: Double, _ unit: Unit) -> Double {
        amount * unit.baseFactor
    }

    /// Renders a base-unit total back into a readable amount, staying within the
    /// same measurement family as `like` (so imperial stays imperial, metric metric).
    static func display(base: Double, like unit: Unit) -> (amount: Double, unit: Unit) {
        switch unit {
        // mass — metric
        case .mg, .g, .kg:
            if base >= 1000 { return (round2(base / 1000), .kg) }
            if base >= 1    { return (round2(base), .g) }
            return (round2(base * 1000), .mg)
        // mass — imperial
        case .oz, .lbs:
            if base >= 453.592 { return (round2(base / 453.592), .lbs) }
            return (round2(base / 28.3495), .oz)
        // volume — metric
        case .ml, .dl, .l:
            if base >= 1000 { return (round2(base / 1000), .l) }
            return (round2(base), .ml)
        // volume — cooking/imperial
        case .tsp, .tbsp, .cup:
            if base >= 240        { return (round2(base / 240), .cup) }
            if base >= 14.7868    { return (round2(base / 14.7868), .tbsp) }
            return (round2(base / 4.92892), .tsp)
        // count — keep as-is
        case .piece, .slice, .pack:
            return (round2(base), unit)
        }
    }

    /// Two units can be auto-summed when they share a dimension. For `count`,
    /// only identical units combine (a slice and a pack aren't the same thing).
    static func canCombine(_ a: Unit, _ b: Unit) -> Bool {
        guard a.dimension == b.dimension else { return false }
        if a.dimension == .count { return a == b }
        return true
    }

    /// Converts to grams when possible: mass directly, volume via density. nil for
    /// count, or volume without a known density.
    static func toGrams(_ amount: Double, _ unit: Unit, density: Double?) -> Double? {
        switch unit.dimension {
        case .mass:   return toBase(amount, unit)
        case .volume: return density.map { toBase(amount, unit) * $0 }
        case .count:  return nil
        }
    }

    /// Combines two quantities of the *same* ingredient into one, returning nil when
    /// they can't be combined. Same-dimension always combines; mass↔volume combines
    /// only when a density is known (result is expressed as mass).
    static func combine(
        _ a: (amount: Double, unit: Unit),
        _ b: (amount: Double, unit: Unit),
        density: Double?
    ) -> (amount: Double, unit: Unit)? {
        if canCombine(a.unit, b.unit) {
            let total = toBase(a.amount, a.unit) + toBase(b.amount, b.unit)
            return display(base: total, like: a.unit)
        }
        let dims: Set<Measure> = [a.unit.dimension, b.unit.dimension]
        if dims == [.mass, .volume],
           let gramsA = toGrams(a.amount, a.unit, density: density),
           let gramsB = toGrams(b.amount, b.unit, density: density) {
            // Express the merged total as mass; keep the existing item's mass family.
            let likeUnit: Unit = a.unit.dimension == .mass ? a.unit : .g
            return display(base: gramsA + gramsB, like: likeUnit)
        }
        return nil
    }

    private static func round2(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}

/// Adds quantities to the shopping list, merging into an existing active item
/// when the ingredient resolves to the same canonical key and a compatible unit.
enum ShoppingListAggregator {

    @discardableResult
    static func add(name: String, amount: Double, unit: Unit, to context: ModelContext) -> ShoppingItem {
        let existing = (try? context.fetch(FetchDescriptor<ShoppingItem>())) ?? []
        let key = IngredientNormalizer.canonicalKey(name)
        let density = IngredientCatalog.density(forKey: key)

        if let match = existing.first(where: {
            !$0.isChecked &&
            IngredientNormalizer.canonicalKey($0.name) == key &&
            UnitConverter.combine(($0.amount, $0.unit), (amount, unit), density: density) != nil
        }),
           let merged = UnitConverter.combine((match.amount, match.unit), (amount, unit), density: density) {
            match.amount = merged.amount
            match.unit = merged.unit
            return match
        }

        let item = ShoppingItem(name: name, amount: amount, unit: unit)
        context.insert(item)
        return item
    }

    /// Consolidates existing active items: within each canonical-ingredient group,
    /// greedily merges anything combinable (incl. mass↔volume via density). Returns
    /// how many items were removed (0 means nothing to merge).
    @discardableResult
    static func consolidate(in context: ModelContext) -> Int {
        let items = (try? context.fetch(FetchDescriptor<ShoppingItem>())) ?? []
        let active = items.filter { !$0.isChecked }

        var byKey: [String: [ShoppingItem]] = [:]
        for item in active { byKey[IngredientNormalizer.canonicalKey(item.name), default: []].append(item) }

        var removed = 0
        for (key, group) in byKey where group.count > 1 {
            let density = IngredientCatalog.density(forKey: key)
            var survivors: [ShoppingItem] = []
            for item in group {
                if let target = survivors.first(where: {
                    UnitConverter.combine(($0.amount, $0.unit), (item.amount, item.unit), density: density) != nil
                }),
                   let merged = UnitConverter.combine((target.amount, target.unit), (item.amount, item.unit), density: density) {
                    target.amount = merged.amount
                    target.unit = merged.unit
                    context.delete(item)
                    removed += 1
                } else {
                    survivors.append(item)
                }
            }
        }
        return removed
    }
}
