//
//  SmartIngredientTests.swift
//  KitchenOSTests
//
//  Tests for the "smart ingredients" work: normalization, unit math,
//  density-based cross-dimension merging, and shopping-list aggregation.
//

import Testing
import SwiftData
@testable import KitchenOS

@MainActor
struct SmartIngredientTests {

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: ShoppingItem.self, configurations: config)
        return ModelContext(container)
    }

    private func activeItems(_ context: ModelContext) -> [ShoppingItem] {
        let all = (try? context.fetch(FetchDescriptor<ShoppingItem>())) ?? []
        return all.filter { !$0.isChecked }
    }

    private func approxEqual(_ a: Double, _ b: Double, tol: Double = 0.05) -> Bool {
        abs(a - b) <= tol
    }

    // MARK: - Normalization

    @Test func canonicalKeyMatchesSynonymsAndLanguages() {
        let flourKey = IngredientNormalizer.canonicalKey("flour")
        #expect(IngredientNormalizer.canonicalKey("All-Purpose Flour") == flourKey)
        #expect(IngredientNormalizer.canonicalKey("plain flour") == flourKey)
        #expect(IngredientNormalizer.canonicalKey("Mehl") == flourKey)        // German
        #expect(IngredientNormalizer.canonicalKey("farine") == flourKey)      // French
    }

    @Test func canonicalKeyStripsDescriptorsAndPlurals() {
        let onionKey = IngredientNormalizer.canonicalKey("onion")
        #expect(IngredientNormalizer.canonicalKey("finely chopped onions") == onionKey)
        #expect(IngredientNormalizer.canonicalKey("Large Onion") == onionKey)

        let tomatoKey = IngredientNormalizer.canonicalKey("tomato")
        #expect(IngredientNormalizer.canonicalKey("fresh tomatoes") == tomatoKey)
    }

    @Test func differentIngredientsStaySeparate() {
        #expect(IngredientNormalizer.canonicalKey("flour") != IngredientNormalizer.canonicalKey("sugar"))
        #expect(IngredientNormalizer.canonicalKey("bread flour") != IngredientNormalizer.canonicalKey("flour"))
    }

    // MARK: - Unit conversion

    @Test func sameDimensionConversion() {
        // 1 kg + 500 g = 1.5 kg
        let merged = UnitConverter.combine((1, .kg), (500, .g), density: nil)
        #expect(merged?.unit == .kg)
        #expect(approxEqual(merged?.amount ?? 0, 1.5))
    }

    @Test func metricUpgradeAndImperialStaysImperial() {
        // grams that exceed 1000 upgrade to kg
        let m1 = UnitConverter.combine((600, .g), (600, .g), density: nil)
        #expect(m1?.unit == .kg)
        #expect(approxEqual(m1?.amount ?? 0, 1.2))

        // imperial stays imperial: 1 lb + 8 oz = 1.5 lbs
        let m2 = UnitConverter.combine((1, .lbs), (8, .oz), density: nil)
        #expect(m2?.unit == .lbs)
        #expect(approxEqual(m2?.amount ?? 0, 1.5))
    }

    @Test func countUnitsOnlyCombineWhenIdentical() {
        #expect(UnitConverter.combine((2, .piece), (3, .piece), density: nil) != nil)
        #expect(UnitConverter.combine((2, .slice), (1, .pack), density: nil) == nil)
        #expect(UnitConverter.combine((2, .piece), (200, .g), density: nil) == nil)
    }

    // MARK: - Cross-dimension via density

    @Test func crossDimensionMergeWithDensity() {
        // 1 cup flour (240 ml * 0.53 = 127.2 g) + 200 g flour ≈ 327 g
        let density = IngredientCatalog.density(forKey: "flour")
        #expect(density != nil)
        let merged = UnitConverter.combine((200, .g), (1, .cup), density: density)
        #expect(merged?.unit == .g)
        #expect(approxEqual(merged?.amount ?? 0, 327.2, tol: 1.0))
    }

    @Test func crossDimensionFailsWithoutDensity() {
        // No density known → cup + g cannot combine.
        let merged = UnitConverter.combine((200, .g), (1, .cup), density: nil)
        #expect(merged == nil)
    }

    // MARK: - Shopping list aggregation

    @Test func aggregatorMergesFlourExample() throws {
        let ctx = try makeContext()
        ShoppingListAggregator.add(name: "flour", amount: 1, unit: .kg, to: ctx)
        ShoppingListAggregator.add(name: "Flour", amount: 500, unit: .g, to: ctx)

        let items = activeItems(ctx)
        #expect(items.count == 1)
        #expect(items.first?.unit == .kg)
        #expect(approxEqual(items.first?.amount ?? 0, 1.5))
    }

    @Test func aggregatorMergesAcrossLanguages() throws {
        let ctx = try makeContext()
        ShoppingListAggregator.add(name: "flour", amount: 200, unit: .g, to: ctx)
        ShoppingListAggregator.add(name: "Mehl", amount: 300, unit: .g, to: ctx)

        let items = activeItems(ctx)
        #expect(items.count == 1)
        #expect(approxEqual(items.first?.amount ?? 0, 500))
    }

    @Test func aggregatorKeepsDifferentIngredientsSeparate() throws {
        let ctx = try makeContext()
        ShoppingListAggregator.add(name: "flour", amount: 1, unit: .kg, to: ctx)
        ShoppingListAggregator.add(name: "sugar", amount: 200, unit: .g, to: ctx)
        #expect(activeItems(ctx).count == 2)
    }

    @Test func aggregatorDoesNotMergeIntoCheckedItem() throws {
        let ctx = try makeContext()
        let first = ShoppingListAggregator.add(name: "milk", amount: 1, unit: .l, to: ctx)
        first.isChecked = true
        ShoppingListAggregator.add(name: "milk", amount: 500, unit: .ml, to: ctx)
        // Checked item is "already bought", so a new active line is created.
        #expect(activeItems(ctx).count == 1)
        let all = (try? ctx.fetch(FetchDescriptor<ShoppingItem>())) ?? []
        #expect(all.count == 2)
    }

    @Test func consolidateMergesExistingDuplicates() throws {
        let ctx = try makeContext()
        // Insert raw duplicates (bypassing the aggregator) to simulate a messy list.
        for (n, a, u) in [("flour", 500.0, Unit.g), ("Flour", 1.0, .kg), ("Mehl", 250.0, .g)] {
            ctx.insert(ShoppingItem(name: n, amount: a, unit: u))
        }
        ctx.insert(ShoppingItem(name: "eggs", amount: 6, unit: .piece))

        let removed = ShoppingListAggregator.consolidate(in: ctx)
        #expect(removed == 2)                 // 3 flours → 1

        let items = activeItems(ctx)
        #expect(items.count == 2)             // flour + eggs
        let flour = items.first { IngredientNormalizer.canonicalKey($0.name) == IngredientNormalizer.canonicalKey("flour") }
        #expect(flour != nil)
        // 500 g + 1000 g + 250 g = 1750 g = 1.75 kg
        #expect(flour?.unit == .kg)
        #expect(approxEqual(flour?.amount ?? 0, 1.75))
    }

    // MARK: - Catalog

    @Test func catalogProvidesCategories() {
        #expect(IngredientCatalog.category(forKey: IngredientNormalizer.canonicalKey("chicken")) == .meat)
        #expect(IngredientCatalog.category(forKey: IngredientNormalizer.canonicalKey("flour")) == .bakingItems)
        #expect(IngredientCatalog.category(forKey: IngredientNormalizer.canonicalKey("onion")) == .produce)
    }
}
