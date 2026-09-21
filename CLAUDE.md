# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Deploy

```bash
# Build (release, for device)
xcodebuild -scheme KitchenOS -destination 'generic/platform=iOS' -configuration Release build

# Bump build number (always do this before archiving)
agvtool bump -all

# Archive + upload to TestFlight in one step
xcodebuild archive \
  -scheme KitchenOS -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath /tmp/KitchenOS_buildN.xcarchive

xcodebuild -exportArchive \
  -archivePath /tmp/KitchenOS_buildN.xcarchive \
  -exportPath /tmp/KitchenOS_buildN_export \
  -exportOptionsPlist ExportOptions.plist
```

The `ExportOptions.plist` at the project root is configured for `app-store-connect` with automatic signing. The export step also uploads to App Store Connect.

## Tests

Both test targets (`KitchenOSTests`, `KitchenOSUITests`) are template stubs — no meaningful tests exist yet.

```bash
xcodebuild test -scheme KitchenOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)'
```

## Architecture

**Stack:** SwiftUI + SwiftData + CloudKit, targeting iPadOS. The app is called MealOS in user-facing copy but KitchenOS in code/bundle ID.

**Navigation:** `ContentView` hosts a `NavigationSplitView` whose sidebar lists 6 destinations: Dashboard, Week Plan, Recipes, Shopping List, Recipe Store, Pantry.

**Persistence:** SwiftData with `cloudKitDatabase: .automatic` syncs 8 `@Model` types to the private CloudKit database automatically. The iCloud container is `iCloud.com.danielgergely.KitchenOS`. SwiftData's automatic sync only mirrors the *private* database.

**Shared meal plan:** A separate CloudKit layer (not SwiftData) handles household sharing:
- `CloudKitSharingCoordinator` (singleton) manages the zone-level `CKShare` for the dedicated `KitchenOS.sharedPlan` zone — *not* SwiftData's `com.apple.coredata.cloudkit.zone`. The owner creates the share; participants accept via a URL. `ownsSharedPlan` / `isInSharedPlan` on the coordinator are the single source of truth for which side the device is on.
- `SharedPlanService` (singleton, `@Observable`) reads/writes to `sharedCloudDatabase` directly via CloudKit API — this data never touches SwiftData. It uses `CKFetchRecordZoneChangesOperation` (not `CKQuery`) to avoid needing queryable-field indices in production.
- NSPersistentCloudKitContainer stores records with a `CD_` prefix: entity `PlannedMeal` → record type `CD_PlannedMeal`, field `notes` → CloudKit key `CD_notes`.
- `WeekPlanView` toggles between `PlanSource.mine` (SwiftData `DayColumn`) and `PlanSource.shared` (`SharedDayColumn` backed by `SharedPlanService`). The toggle appears for both owners (`coordinator.currentShare != nil`) and participants (`sharedPlan.hasAcceptedShare`).

**Model ↔ DTO mapping:** `Mappers/RecipeTransfer.swift` is the only place that converts between `Recipe`/`Ingredient`/`Tag` and their `Transfer*` Codable counterparts. Export, shared-plan snapshots, import, opening a shared recipe, and saving one to the library all go through it — don't hand-roll the mapping again.

**Actor isolation:** the project builds with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (Swift 5 mode), so unannotated types are main-actor isolated. Pure computation that shouldn't block the UI (e.g. `RecipeJSONLDExtractor`) is marked `nonisolated` *and* dispatched via `Task.detached` — `nonisolated` alone still runs on the caller's executor.

**Services pattern:** All services are `@Observable` singletons accessed via `.shared`. They are injected into the SwiftUI environment in `KitchenOSApp` and consumed with `@Environment(ServiceType.self)`.

**External integrations:** API keys live in `Config.xcconfig` (not checked in to version control) and are surfaced through `ConfigService`/`Secrets`. The app uses Google Gemini via `AIService` (recipe extraction from images/URLs, and library recommendations) and Supabase (recipe store, `RecipeStoreService` + `AdminPublishService`).

URL recipe import tries `RecipeJSONLDExtractor` (schema.org JSON-LD, free and on-device) first and only falls back to Gemini when a page has no structured data. `RecipeLanguage` (Settings → Recipe Language) decides the language the model writes the extracted recipe in.

## SourceKit False Positives

SourceKit reports "Cannot find type X in scope" for cross-file same-module references (`MealType`, `Recipe`, `Day`, `CookingType`, `TransferRecipe`, etc.). These are false positives — the compiler resolves them correctly and builds succeed. Ignore SourceKit errors; trust `** BUILD SUCCEEDED **`.

## CloudKit Schema Notes

- Production CloudKit does **not** support `CKQuery` with `NSPredicate(value: true)` on NSPersistentCloudKitContainer-managed record types — you'll get `'recordName' is not queryable`. Use `CKFetchRecordZoneChangesOperation` instead.
- When creating a zone-level share after a reinstall (UserDefaults cleared), `CloudKitSharingCoordinator.fetchPersistedShare()` falls back to scanning the private zone via `CKFetchRecordZoneChangesOperation` to recover the existing `CKShare` before attempting to create a duplicate.
