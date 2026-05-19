//
//  SharedPlanService.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 5/19/26.
//

// Architecture note:
// The shared meal plan lives in a dedicated CloudKit zone "KitchenOS.sharedPlan",
// separate from SwiftData's "com.apple.coredata.cloudkit.zone". This avoids all
// NSPersistentCloudKitContainer interference (schema conflicts, competing zone
// change subscriptions, CD_* type mismatches).
//
// Owner  → reads/writes privateCloudDatabase  zone "KitchenOS.sharedPlan"
// Guest  → reads/writes sharedCloudDatabase   zone "KitchenOS.sharedPlan" (shared TO them)
//
// Record type "SharedMeal" has fields: date (Date), mealType (String),
// title (String?), notes (String), recipeData (Data?).
// No parent "Day" record needed — date is stored directly on each meal.

import Foundation
import CloudKit
import SwiftUI

struct SharedMealEntry: Identifiable {
    let id: String
    let date: Date
    let mealType: MealType
    let recipeTitle: String?
    let notes: String
    let sharedRecipeData: Data?
    let imageData: Data?
}

@Observable
final class SharedPlanService {

    static let shared = SharedPlanService()

    static let zoneName = "KitchenOS.sharedPlan"
    private static let acceptedKey = "sharedPlan.hasAccepted"
    private let ck = CKContainer(identifier: "iCloud.com.danielgergely.KitchenOS")

    private(set) var meals: [SharedMealEntry] = []
    private(set) var isLoading = false
    private(set) var error: String?
    private(set) var hasAcceptedShare: Bool = UserDefaults.standard.bool(forKey: acceptedKey)
    private(set) var ownerDisplayName: String?
    private(set) var sharedZoneID: CKRecordZone.ID?

    // MARK: - Acceptance

    func accept(metadata: CKShare.Metadata) async {
        do {
            try await ck.accept(metadata)
            UserDefaults.standard.set(true, forKey: Self.acceptedKey)
            hasAcceptedShare = true
            if let components = metadata.ownerIdentity.nameComponents {
                ownerDisplayName = PersonNameComponentsFormatter().string(from: components)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Fetch

    func fetchMeals(for weekDates: [Date], isOwner: Bool) async {
        guard (hasAcceptedShare || isOwner), let first = weekDates.first, let last = weekDates.last else { return }
        isLoading = true
        defer { isLoading = false }
        error = nil

        let weekStart = Calendar.current.startOfDay(for: first)
        let weekEnd   = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: last)!
        )

        do {
            let database = isOwner ? ck.privateCloudDatabase : ck.sharedCloudDatabase
            let zones = try await database.allRecordZones()

            guard let zone = zones.first(where: { $0.zoneID.zoneName == Self.zoneName }) else {
                meals = []
                // Not an error for the owner — zone doesn't exist until first share is set up.
                if !isOwner {
                    error = "Shared zone not found. Make sure the owner has shared their plan and iCloud has synced."
                }
                return
            }

            sharedZoneID = zone.zoneID
            let allRecords = try await fetchZoneRecords(from: zone, in: database)

            meals = allRecords.compactMap { rec -> SharedMealEntry? in
                guard rec.recordType == "SharedMeal",
                      let date = rec["date"] as? Date,
                      date >= weekStart, date < weekEnd
                else { return nil }

                let typeRaw  = rec["mealType"] as? String ?? MealType.dinner.rawValue
                let mealType = MealType(rawValue: typeRaw) ?? .dinner
                let snapData = rec["recipeData"] as? Data
                let imageData = snapData.flatMap {
                    (try? JSONDecoder().decode(TransferRecipe.self, from: $0))?.imageData
                }
                return SharedMealEntry(
                    id: rec.recordID.recordName,
                    date: date,
                    mealType: mealType,
                    recipeTitle: rec["title"] as? String,
                    notes: rec["notes"] as? String ?? "",
                    sharedRecipeData: snapData,
                    imageData: imageData
                )
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Write

    func addMeal(date: Date, mealType: MealType, title: String?, notes: String, recipeData: Data?, isOwner: Bool) async {
        do {
            let zoneID   = try await resolveZoneID(isOwner: isOwner)
            let database = isOwner ? ck.privateCloudDatabase : ck.sharedCloudDatabase

            let record = CKRecord(recordType: "SharedMeal", recordID: CKRecord.ID(zoneID: zoneID))
            record["date"]     = Calendar.current.startOfDay(for: date) as CKRecordValue
            record["mealType"] = mealType.rawValue as CKRecordValue
            record["notes"]    = notes as CKRecordValue
            if let t = title, !t.isEmpty { record["title"] = t as CKRecordValue }
            if let data = recipeData      { record["recipeData"] = data as CKRecordValue }

            let saved = try await database.save(record)
            let imageData = recipeData.flatMap {
                (try? JSONDecoder().decode(TransferRecipe.self, from: $0))?.imageData
            }
            meals.append(SharedMealEntry(
                id: saved.recordID.recordName,
                date: Calendar.current.startOfDay(for: date),
                mealType: mealType,
                recipeTitle: title,
                notes: notes,
                sharedRecipeData: recipeData,
                imageData: imageData
            ))
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteMeal(id: String, isOwner: Bool) async {
        do {
            let zoneID   = try await resolveZoneID(isOwner: isOwner)
            let database = isOwner ? ck.privateCloudDatabase : ck.sharedCloudDatabase
            try await database.deleteRecord(withID: CKRecord.ID(recordName: id, zoneID: zoneID))
            meals.removeAll { $0.id == id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func clearAcceptedShare() {
        UserDefaults.standard.removeObject(forKey: Self.acceptedKey)
        hasAcceptedShare = false
        ownerDisplayName = nil
        meals = []
        sharedZoneID = nil
    }

    // MARK: - Private helpers

    private func resolveZoneID(isOwner: Bool) async throws -> CKRecordZone.ID {
        if let id = sharedZoneID { return id }
        let database = isOwner ? ck.privateCloudDatabase : ck.sharedCloudDatabase
        let zones = try await database.allRecordZones()
        guard let zone = zones.first(where: { $0.zoneID.zoneName == Self.zoneName }) else {
            throw NSError(domain: "SharedPlan", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Shared plan zone not found. Ensure the owner has set up sharing."
            ])
        }
        sharedZoneID = zone.zoneID
        return zone.zoneID
    }

    private func fetchZoneRecords(from zone: CKRecordZone, in database: CKDatabase) async throws -> [CKRecord] {
        var collected: [CKRecord] = []
        var serverToken: CKServerChangeToken? = nil

        repeat {
            let page = try await fetchPage(zoneID: zone.zoneID, serverToken: serverToken, in: database)
            collected.append(contentsOf: page.records)
            serverToken = page.nextToken
            if !page.moreComing { break }
        } while true

        return collected
    }

    private func fetchPage(
        zoneID: CKRecordZone.ID,
        serverToken: CKServerChangeToken?,
        in database: CKDatabase
    ) async throws -> (records: [CKRecord], nextToken: CKServerChangeToken?, moreComing: Bool) {

        final class State {
            var records: [CKRecord] = []
            var nextToken: CKServerChangeToken?
            var moreComing = false
        }
        let state = State()

        let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        config.previousServerChangeToken = serverToken

        let op = CKFetchRecordZoneChangesOperation(
            recordZoneIDs: [zoneID],
            configurationsByRecordZoneID: [zoneID: config]
        )
        op.recordWasChangedBlock = { _, result in
            if let r = try? result.get() { state.records.append(r) }
        }
        op.recordZoneFetchResultBlock = { _, result in
            if case .success(let (token, _, more)) = result {
                state.nextToken = token
                state.moreComing = more
            }
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            op.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:          cont.resume()
                case .failure(let err): cont.resume(throwing: err)
                }
            }
            database.add(op)
        }
        return (state.records, state.nextToken, state.moreComing)
    }
}
