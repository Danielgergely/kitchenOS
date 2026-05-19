//
//  KitchenOSApp.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 2/16/26.
//

import SwiftUI
import SwiftData
import CoreData
import CloudKit

@main
struct KitchenOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Ingredient.self,
            RecipeBook.self,
            Recipe.self,
            PlannedMeal.self,
            ShoppingItem.self,
            Tag.self,
            Day.self,
            UserPreferences.self,
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            #if DEBUG
            initializeCloudKitSchemaIfNeeded(container: container)
            #endif
            return container
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

// Handles the "Join shared plan" tap from iMessage / Mail / etc.
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith metadata: CKShare.Metadata
    ) {
        Task {
            await CloudKitSharingCoordinator.shared.accept(shareMetadata: metadata)
        }
    }
}

// Run once in debug to push the CloudKit schema to Apple's servers.
// After running, go to: CloudKit Dashboard → Development → Deploy Schema to Production
// This block does nothing in release builds.
#if DEBUG
private func initializeCloudKitSchemaIfNeeded(container: ModelContainer) {
    guard let storeURL = container.configurations.first?.url else { return }
    let desc = NSPersistentStoreDescription(url: storeURL)
    desc.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
        containerIdentifier: "iCloud.com.danielgergely.KitchenOS"
    )
    let coreDataContainer = NSPersistentCloudKitContainer(name: "KitchenOS")
    coreDataContainer.persistentStoreDescriptions = [desc]
    try? coreDataContainer.initializeCloudKitSchema(options: [])
}
#endif
