//
//  CloudKitAvailability.swift
//  KitchenOS
//
//  CKContainer(identifier:) *traps* — it does not throw — when the running
//  process has no iCloud entitlement. This app's simulator builds are signed
//  without entitlements (`codesign -d --entitlements` on the .app reports none),
//  so the first CloudKit call killed the app on launch:
//
//      WeekPlanView.onAppear -> fetchPersistedShare -> CKContainer.init -> trap
//
//  That also made the unit tests unrunnable, since KitchenOSTests uses the app
//  as its test host and went down with it.
//
//  Marking the container `lazy` only moved the trap later; it has to not be
//  constructed at all. Device builds carry the entitlement
//  (com.apple.developer.icloud-container-identifiers), so `isAvailable` is
//  unconditionally true there and every CloudKit path behaves exactly as before.
//
//  If you do have a simulator signed with iCloud entitlements, set
//  KITCHENOS_ENABLE_CLOUDKIT=1 in the scheme's environment to opt back in.
//

import CloudKit

enum CloudKitAvailability {

    static let containerIdentifier = "iCloud.com.danielgergely.KitchenOS"

    /// True when this build may talk to CloudKit at all.
    static let isAvailable: Bool = {
        #if targetEnvironment(simulator)
        return ProcessInfo.processInfo.environment["KITCHENOS_ENABLE_CLOUDKIT"] != nil
        #else
        return true
        #endif
    }()

    /// The app's CloudKit container, or nil when this build can't reach CloudKit.
    /// Callers treat nil as "sharing is unavailable" and no-op.
    static let container: CKContainer? = isAvailable
        ? CKContainer(identifier: containerIdentifier)
        : nil

    /// Shown when something needs CloudKit but this build can't reach it.
    static let unavailableMessage = "iCloud sharing isn't available in this build."
}
