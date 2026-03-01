//
//  KitchenOSApp.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 2/16/26.
//

import SwiftUI
import SwiftData

@main
struct KitchenOSApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Ingredient.self,
            RecipeBook.self,
            Recipe.self,
            PlannedMeal.self,
            Tag.self,
            Day.self
            ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
