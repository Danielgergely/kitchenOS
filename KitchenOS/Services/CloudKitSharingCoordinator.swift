//
//  CloudKitSharingCoordinator.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 5/18/26.
//

import Foundation
import CloudKit
import SwiftUI

// Manages sharing the household meal plan via CloudKit zone-level sharing.
//
// SwiftData's cloudKitDatabase: .automatic writes all records into a zone named
// "com.apple.coredata.cloudkit.zone". A zone-level CKShare makes every record
// in that zone accessible to all accepted participants, which is exactly the
// "one shared plan per household" model we want.
//
// IMPORTANT — two real requirements for sharing to work:
//   1. The user must be signed into iCloud (Settings → Apple ID)
//   2. The zone must exist on the CloudKit server, meaning at least one SwiftData
//      sync must have completed. Open the app, add any recipe or plan item, wait
//      a moment for the first background sync, then tap Share.
@Observable
final class CloudKitSharingCoordinator {

    static let shared = CloudKitSharingCoordinator()

    private let container = CKContainer(identifier: "iCloud.com.danielgergely.KitchenOS")

    // The zone SwiftData uses — hard-coded by NSPersistentCloudKitContainer.
    static let swiftDataZoneName = "com.apple.coredata.cloudkit.zone"
    static let swiftDataZoneID = CKRecordZone.ID(
        zoneName: swiftDataZoneName,
        ownerName: CKCurrentUserDefaultName
    )

    private let shareRecordIDKey = "kitchenOS.shareRecordID"

    private(set) var shareURL: URL?
    private(set) var currentShare: CKShare?
    private(set) var isOwner: Bool = true
    private(set) var participants: [CKShare.Participant] = []
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?
    private(set) var iCloudStatus: CKAccountStatus = .couldNotDetermine

    // MARK: - Public API

    /// Callback-based share preparation — called by UICloudSharingController's preparationHandler.
    /// Creates the zone-level CKShare if one doesn't exist yet, or returns the existing one.
    func prepareShare(completion: @escaping (CKShare?, CKContainer, Error?) -> Void) {
        Task {
            do {
                // Restore existing share first.
                if let existing = try await fetchPersistedShare() {
                    applyShare(existing)
                    completion(existing, container, nil)
                    return
                }

                let status = try await container.accountStatus()
                iCloudStatus = status
                guard status == .available else {
                    completion(nil, container,
                        NSError(domain: "CloudKitSharing", code: 1, userInfo: [
                            NSLocalizedDescriptionKey: "Not signed in to iCloud. Go to Settings → Apple ID."
                        ]))
                    return
                }

                // Ensure the SwiftData zone exists before attaching a share to it.
                let zone = CKRecordZone(zoneID: Self.swiftDataZoneID)
                _ = try await container.privateCloudDatabase.save(zone)

                let share = CKShare(recordZoneID: Self.swiftDataZoneID)
                share[CKShare.SystemFieldKey.title] = "My Meal Plan" as CKRecordValue
                share.publicPermission = .none

                let results = try await container.privateCloudDatabase.modifyRecords(
                    saving: [share], deleting: [])

                if let saved = try results.saveResults[share.recordID]?.get() as? CKShare {
                    applyShare(saved)
                    completion(saved, container, nil)
                } else {
                    completion(nil, container,
                        NSError(domain: "CloudKitSharing", code: 2, userInfo: [
                            NSLocalizedDescriptionKey: "Share record was not returned after save."
                        ]))
                }
            } catch {
                completion(nil, container, error)
            }
        }
    }

    func checkAccountStatus() async {
        do {
            iCloudStatus = try await container.accountStatus()
        } catch {
            iCloudStatus = .couldNotDetermine
        }
    }

    /// Reconnects to a previously created share (from UserDefaults) without creating a new one.
    /// Call on `.onAppear` so the Manage button appears if a share already exists.
    func loadOrCreateShare(ifExists: Bool) async {
        guard ifExists else { await loadOrCreateShare(); return }
        do {
            if let existing = try await fetchPersistedShare() {
                applyShare(existing)
            }
            iCloudStatus = (try? await container.accountStatus()) ?? .couldNotDetermine
        } catch {
            // Silently ignore — no share was stored.
        }
    }

    /// Creates or retrieves the zone-level CKShare. Call before presenting the share sheet.
    func loadOrCreateShare() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // Guard: iCloud must be signed in.
            let status = try await container.accountStatus()
            iCloudStatus = status
            guard status == .available else {
                errorMessage = "Sign in to iCloud in Settings → Apple ID, then try again."
                return
            }

            // Restore existing share first.
            if let existing = try await fetchPersistedShare() {
                applyShare(existing)
                return
            }

            // Ensure the SwiftData zone exists on the server before creating a share for it.
            // If the zone doesn't exist yet (no sync has completed), create it explicitly.
            let zone = CKRecordZone(zoneID: Self.swiftDataZoneID)
            _ = try await container.privateCloudDatabase.save(zone)

            // Create a zone-level share. This makes all records in the zone visible to participants.
            let share = CKShare(recordZoneID: Self.swiftDataZoneID)
            share[CKShare.SystemFieldKey.title] = "My Meal Plan" as CKRecordValue
            share.publicPermission = .none

            let savedRecords = try await container.privateCloudDatabase.modifyRecords(
                saving: [share],
                deleting: []
            )

            if let savedShare = try savedRecords.saveResults[share.recordID]?.get() as? CKShare {
                applyShare(savedShare)
            } else {
                throw NSError(domain: "CloudKitSharing", code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Share record was not returned after save."])
            }

        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    /// Reload participant list and share URL from CloudKit.
    func refreshShare() async {
        guard let share = currentShare else { return }
        do {
            if let refreshed = try await container.privateCloudDatabase.record(for: share.recordID) as? CKShare {
                applyShare(refreshed)
            }
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    func stopSharing() async {
        guard let share = currentShare else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await container.privateCloudDatabase.deleteRecord(withID: share.recordID)
            UserDefaults.standard.removeObject(forKey: shareRecordIDKey)
            currentShare = nil
            shareURL = nil
            participants = []
            isOwner = true
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    func remove(participant: CKShare.Participant) async {
        guard let share = currentShare else { return }
        share.removeParticipant(participant)
        do {
            let results = try await container.privateCloudDatabase.modifyRecords(saving: [share], deleting: [])
            if let saved = try results.saveResults[share.recordID]?.get() as? CKShare {
                applyShare(saved)
            }
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    /// Called from AppDelegate when the user taps an iMessage/Mail share link.
    func accept(shareMetadata: CKShare.Metadata) async {
        do {
            try await container.accept(shareMetadata)
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    var canEdit: Bool {
        guard let participant = currentShare?.currentUserParticipant else { return true }
        return participant.permission == .readWrite || participant.role == .owner
    }

    // MARK: - Private

    private func fetchPersistedShare() async throws -> CKShare? {
        guard
            let data = UserDefaults.standard.data(forKey: shareRecordIDKey),
            let recordID = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKRecord.ID.self, from: data)
        else { return nil }

        // The persisted share might have been deleted on another device — handle gracefully.
        do {
            let record = try await container.privateCloudDatabase.record(for: recordID)
            return record as? CKShare
        } catch let ckError as CKError where ckError.code == .unknownItem {
            UserDefaults.standard.removeObject(forKey: shareRecordIDKey)
            return nil
        }
    }

    private func applyShare(_ share: CKShare) {
        currentShare = share
        shareURL = share.url
        participants = share.participants
        isOwner = share.currentUserParticipant?.role == .owner

        if let data = try? NSKeyedArchiver.archivedData(withRootObject: share.recordID, requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: shareRecordIDKey)
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .notAuthenticated:
                return "Not signed in to iCloud. Go to Settings → Apple ID and sign in."
            case .networkUnavailable, .networkFailure:
                return "No internet connection. Please try again."
            case .serverRejectedRequest:
                // This usually means the zone doesn't have records yet.
                let detail = ckError.userInfo[NSLocalizedDescriptionKey] as? String ?? ""
                return "iCloud couldn't create the share. Make sure you've added at least one recipe or meal, wait a moment for iCloud sync, then try again. (\(ckError.errorCode)\(detail.isEmpty ? "" : ": \(detail)"))"
            case .quotaExceeded:
                return "iCloud storage is full. Free up space and try again."
            case .zoneNotFound:
                return "iCloud zone not ready yet. Add some data and wait a moment for the first sync, then try again."
            case .unknownItem:
                return "The previous share link expired. Please tap Share again to create a new one."
            default:
                break
            }
        }
        return error.localizedDescription
    }
}
