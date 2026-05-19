//
//  CloudSharingView.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 5/18/26.
//

import SwiftUI
import CloudKit

// Wraps UICloudSharingController in two modes:
//   .invite  — uses preparationHandler, which presents the full iOS share sheet
//              (Messages, AirDrop, Copy Link…). Creates the CKShare during presentation.
//   .manage  — uses init(share:container:), which shows the participant management UI
//              for an already-active share (add/remove people, change permissions).
struct CloudSharingView: UIViewControllerRepresentable {

    enum Mode {
        case invite(coordinator: CloudKitSharingCoordinator)
        case manage(share: CKShare, container: CKContainer)
    }

    let mode: Mode
    var onDone: (() -> Void)? = nil

    private static let ckContainer = CKContainer(identifier: "iCloud.com.danielgergely.KitchenOS")

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let ctrl: UICloudSharingController

        switch mode {
        case .invite(let coordinator):
            ctrl = UICloudSharingController { _, preparationHandler in
                coordinator.prepareShare(completion: preparationHandler)
            }

        case .manage(let share, let container):
            ctrl = UICloudSharingController(share: share, container: container)
        }

        ctrl.availablePermissions = [.allowReadWrite, .allowReadOnly]
        ctrl.delegate = context.coordinator
        return ctrl
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let onDone: (() -> Void)?
        init(onDone: (() -> Void)?) { self.onDone = onDone }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            print("CloudKit share save failed: \(error.localizedDescription)")
        }

        func itemTitle(for csc: UICloudSharingController) -> String? { "My Meal Plan" }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            onDone?()
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            onDone?()
        }
    }
}
