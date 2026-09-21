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
// The share covers the dedicated zone "KitchenOS.sharedPlan" (see SharedPlanService)
// — NOT SwiftData's own "com.apple.coredata.cloudkit.zone". Keeping them separate
// means NSPersistentCloudKitContainer never competes with us over the same records.
// A zone-level CKShare makes every record in that zone accessible to all accepted
// participants, which is the "one shared plan per household" model we want.
//
// The one real requirement: the user must be signed into iCloud (Settings → Apple ID).
// The zone itself is created on demand when the share is set up.
@Observable
final class CloudKitSharingCoordinator {

    static let shared = CloudKitSharingCoordinator()

    static let containerIdentifier = CloudKitAvailability.containerIdentifier

    // nil when the build has no iCloud entitlement (see CloudKitAvailability).
    // Every entry point below no-ops in that case rather than trapping.
    @ObservationIgnored private let container = CloudKitAvailability.container

    // Dedicated zone for the collaborative shared plan — separate from SwiftData's zone
    // so NSPersistentCloudKitContainer never interferes with reads/writes here.
    static let sharedPlanZoneID = CKRecordZone.ID(
        zoneName: SharedPlanService.zoneName,
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

    /// Returns the zone-level CKShare, creating it (and its zone) on first use.
    /// This is the single share-creation path; the callback variant below wraps it.
    @discardableResult
    func loadOrCreateShare() async throws -> CKShare {
        guard let container else {
            throw NSError(domain: "CloudKitSharing", code: 3, userInfo: [
                NSLocalizedDescriptionKey: CloudKitAvailability.unavailableMessage
            ])
        }

        // Restore an existing share first — upgrade permission if it was created with .none.
        if let existing = try await fetchPersistedShare() {
            let upgraded = try await ensureReadWritePermission(existing)
            applyShare(upgraded)
            return upgraded
        }

        let status = try await container.accountStatus()
        iCloudStatus = status
        guard status == .available else {
            throw NSError(domain: "CloudKitSharing", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Not signed in to iCloud. Go to Settings → Apple ID."
            ])
        }

        let zone = CKRecordZone(zoneID: Self.sharedPlanZoneID)
        _ = try await container.privateCloudDatabase.save(zone)

        let share = CKShare(recordZoneID: Self.sharedPlanZoneID)
        share[CKShare.SystemFieldKey.title] = "My Meal Plan" as CKRecordValue
        // .readWrite lets anyone who receives the URL accept the share.
        // The link is sent directly to a trusted person, so this is safe.
        share.publicPermission = .readWrite

        let results = try await container.privateCloudDatabase.modifyRecords(saving: [share], deleting: [])
        guard let saved = try results.saveResults[share.recordID]?.get() as? CKShare else {
            throw NSError(domain: "CloudKitSharing", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Share record was not returned after save."
            ])
        }
        applyShare(saved)
        return saved
    }

    /// Callback-based share preparation — used by SharePlanSheet and
    /// UICloudSharingController's preparationHandler.
    func prepareShare(completion: @escaping (CKShare?, CKContainer, Error?) -> Void) {
        guard let container else {
            completion(nil, CKContainer.default(), NSError(domain: "CloudKitSharing", code: 3, userInfo: [
                NSLocalizedDescriptionKey: CloudKitAvailability.unavailableMessage
            ]))
            return
        }
        Task {
            do {
                completion(try await loadOrCreateShare(), container, nil)
            } catch {
                completion(nil, container, error)
            }
        }
    }

    func checkAccountStatus() async {
        guard let container else { iCloudStatus = .noAccount; return }
        do {
            iCloudStatus = try await container.accountStatus()
        } catch {
            iCloudStatus = .couldNotDetermine
        }
    }

    /// Reconnects to a previously created share without creating a new one.
    /// Call on `.onAppear` so the sharing UI reflects an existing share.
    func refreshExistingShare() async {
        guard let container else { return }
        if let existing = try? await fetchPersistedShare() {
            applyShare(existing)
        }
        iCloudStatus = (try? await container.accountStatus()) ?? .couldNotDetermine
    }

    /// Reload participant list and share URL from CloudKit.
    func refreshShare() async {
        guard let container, let share = currentShare else { return }
        do {
            if let refreshed = try await container.privateCloudDatabase.record(for: share.recordID) as? CKShare {
                applyShare(refreshed)
            }
        } catch {
            errorMessage = Self.friendlyMessage(for: error)
        }
    }

    func stopSharing() async {
        guard let container, let share = currentShare else { return }
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
            errorMessage = Self.friendlyMessage(for: error)
        }
    }

    func remove(participant: CKShare.Participant) async {
        guard let container, let share = currentShare else { return }
        share.removeParticipant(participant)
        do {
            let results = try await container.privateCloudDatabase.modifyRecords(saving: [share], deleting: [])
            if let saved = try results.saveResults[share.recordID]?.get() as? CKShare {
                applyShare(saved)
            }
        } catch {
            errorMessage = Self.friendlyMessage(for: error)
        }
    }

    /// Called from AppDelegate when the user taps an iMessage/Mail share link.
    func accept(shareMetadata: CKShare.Metadata) async {
        guard let container else { return }
        do {
            _ = try await container.accept(shareMetadata)
        } catch {
            errorMessage = Self.friendlyMessage(for: error)
        }
    }

    /// True when this device created the share, i.e. it owns the shared-plan zone.
    /// (A device that accepted someone else's share is never the owner.)
    var ownsSharedPlan: Bool {
        currentShare != nil && !SharedPlanService.shared.hasAcceptedShare
    }

    /// True when the user takes part in a shared plan, from either side.
    var isInSharedPlan: Bool {
        SharedPlanService.shared.hasAcceptedShare || ownsSharedPlan
    }

    var canEdit: Bool {
        guard let participant = currentShare?.currentUserParticipant else { return true }
        return participant.permission == .readWrite || participant.role == .owner
    }

    // MARK: - Private

    /// If an existing share has publicPermission == .none it will silently reject everyone
    /// who taps the link ("Item Unavailable"). Upgrade it to .readWrite so any recipient
    /// of the URL can accept without needing to be pre-approved.
    private func ensureReadWritePermission(_ share: CKShare) async throws -> CKShare {
        guard let container, share.publicPermission != .readWrite else { return share }
        share.publicPermission = .readWrite
        let results = try await container.privateCloudDatabase.modifyRecords(saving: [share], deleting: [])
        return (try results.saveResults[share.recordID]?.get() as? CKShare) ?? share
    }

    /// Returns the existing CKShare, checking UserDefaults first then scanning the zone
    /// directly on the server. The zone scan handles reinstalls where UserDefaults was cleared.
    private func fetchPersistedShare() async throws -> CKShare? {
        guard let container else { return nil }

        // 1. Fast path: cached record ID in UserDefaults
        if let data = UserDefaults.standard.data(forKey: shareRecordIDKey),
           let recordID = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKRecord.ID.self, from: data) {
            do {
                let record = try await container.privateCloudDatabase.record(for: recordID)
                return record as? CKShare
            } catch let ckError as CKError where ckError.code == .unknownItem {
                UserDefaults.standard.removeObject(forKey: shareRecordIDKey)
            }
        }

        // 2. Slow path: UserDefaults was cleared (reinstall). Scan the private zone for
        //    the existing CKShare record — zone-level shares live in the zone itself.
        return try await fetchShareFromZone()
    }

    /// Fetches the CKShare record from the dedicated shared-plan zone by scanning all
    /// zone records with a nil server token. Returns nil if the zone doesn't exist yet.
    private func fetchShareFromZone() async throws -> CKShare? {
        guard let container else { return nil }

        final class State {
            var share: CKShare?
            var nextToken: CKServerChangeToken?
            var moreComing = false
        }
        var serverToken: CKServerChangeToken? = nil

        repeat {
            let state = State()
            let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            config.previousServerChangeToken = serverToken

            let op = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [Self.sharedPlanZoneID],
                configurationsByRecordZoneID: [Self.sharedPlanZoneID: config]
            )

            op.recordWasChangedBlock = { _, result in
                if let s = (try? result.get()) as? CKShare { state.share = s }
            }
            op.recordZoneFetchResultBlock = { _, result in
                if case .success(let (token, _, more)) = result {
                    state.nextToken = token
                    state.moreComing = more
                }
            }

            do {
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                    op.fetchRecordZoneChangesResultBlock = { (result: Result<Void, Error>) in
                        switch result {
                        case .success:          cont.resume()
                        case .failure(let err): cont.resume(throwing: err)
                        }
                    }
                    container.privateCloudDatabase.add(op)
                }
            } catch let ckError as CKError where ckError.code == .zoneNotFound {
                return nil  // Zone doesn't exist yet — no share stored
            }

            if let found = state.share { return found }
            if !state.moreComing { break }
            serverToken = state.nextToken
        } while true

        return nil
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

    /// Turns a CloudKit error into something a person can act on.
    /// Shared with the share sheet so both surfaces say the same thing.
    static func friendlyMessage(for error: Error) -> String {
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
