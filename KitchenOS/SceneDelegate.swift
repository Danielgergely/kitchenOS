//
//  SceneDelegate.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 5/19/26.
//

// SwiftUI apps use the scene lifecycle, so iOS calls
// windowScene(_:userDidAcceptCloudKitShareWith:) on UIWindowSceneDelegate,
// NOT application(_:userDidAcceptCloudKitShareWith:) on UIApplicationDelegate
// (that one may only fire on cold-launch). Both are implemented for safety.

import UIKit
import CloudKit

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith metadata: CKShare.Metadata
    ) {
        Task {
            await CloudKitSharingCoordinator.shared.accept(shareMetadata: metadata)
            await SharedPlanService.shared.accept(metadata: metadata)
        }
    }
}
