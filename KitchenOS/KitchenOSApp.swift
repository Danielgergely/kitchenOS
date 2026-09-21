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
    // Use the singleton so AppDelegate's async accept() updates the same instance SwiftUI observes.
    let sharedPlanService = SharedPlanService.shared
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
        // Skip CloudKit while running tests — the test host has no iCloud account,
        // and creating a CloudKit-backed store there crashes before tests can run.
        let env = ProcessInfo.processInfo.environment
        let isTesting = env["XCTestConfigurationFilePath"] != nil
            || env["XCTestBundlePath"] != nil
            || NSClassFromString("XCTestCase") != nil

        if !isTesting {
            let cloudConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )
            if let container = try? ModelContainer(for: schema, configurations: [cloudConfig]) {
                return container
            }
        }

        // Fallback: a local store with no CloudKit. Keeps the app usable when iCloud
        // is unavailable (signed-out users, restricted devices) instead of crashing.
        let localConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isTesting,
            cloudKitDatabase: .none
        )
        if let container = try? ModelContainer(for: schema, configurations: [localConfig]) {
            return container
        }

        // Last resort: in-memory, so the app always launches.
        let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [memoryConfig])
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .environment(sharedPlanService)
    }
}

// Handles the "Join shared plan" tap from iMessage / Mail / etc.
class AppDelegate: NSObject, UIApplicationDelegate {

    // Cold-launch path: app not running when share link is tapped.
    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith metadata: CKShare.Metadata
    ) {
        Task {
            await CloudKitSharingCoordinator.shared.accept(shareMetadata: metadata)
            await SharedPlanService.shared.accept(metadata: metadata)
        }
    }

    // Warm-launch / foreground path: register SceneDelegate so iOS calls
    // windowScene(_:userDidAcceptCloudKitShareWith:) when the app is already running.
    func application(
        _ application: UIApplication,
        configurationForConnecting session: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: session.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}
