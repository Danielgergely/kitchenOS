//
//  SharingSheet.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 5/19/26.
//

import SwiftUI
import CloudKit

/// Shown when the user taps the sharing icon in the week plan toolbar.
/// Displays sharing state and management options for both owners and participants.
struct SharingSheet: View {
    let coordinator: CloudKitSharingCoordinator
    @Environment(SharedPlanService.self) private var sharedPlan
    @Environment(\.dismiss) private var dismiss

    @State private var showSharePlanSheet = false
    @State private var showManageAccessSheet = false
    @State private var showStopSharingAlert = false

    var body: some View {
        NavigationStack {
            Form {
                if let share = coordinator.currentShare {
                    ownerSection(share: share)
                } else if sharedPlan.hasAcceptedShare {
                    participantSection
                } else {
                    notSharingSection
                }

                if let msg = coordinator.errorMessage {
                    Section {
                        Text(msg).font(.caption).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Meal Plan Sharing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showSharePlanSheet) {
                SharePlanSheet(coordinator: coordinator) {
                    Task { await coordinator.refreshShare() }
                }
            }
            .sheet(isPresented: $showManageAccessSheet) {
                if let share = coordinator.currentShare {
                    CloudSharingView(
                        mode: .manage(
                            share: share,
                            container: CKContainer(identifier: CloudKitSharingCoordinator.containerIdentifier)
                        )
                    ) {
                        Task { await coordinator.refreshShare() }
                    }
                    .ignoresSafeArea()
                }
            }
            .alert("Stop Sharing?", isPresented: $showStopSharingAlert) {
                Button("Stop Sharing", role: .destructive) {
                    Task {
                        await coordinator.stopSharing()
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove access for everyone you've shared with. Their copy of the plan will no longer update.")
            }
        }
        .onAppear {
            Task { await coordinator.refreshExistingShare() }
        }
    }

    // MARK: - Owner view

    @ViewBuilder
    private func ownerSection(share: CKShare) -> some View {
        let guests = share.participants.filter { $0.role != .owner }

        Section(header: Text("Shared with")) {
            if guests.isEmpty {
                Label("Invite pending — no one has joined yet", systemImage: "person.badge.clock")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(guests, id: \.userIdentity.userRecordID?.recordName) { p in
                    HStack {
                        Image(systemName: "person.fill").foregroundStyle(.blue)
                        Text(p.userIdentity.nameComponents.map {
                            PersonNameComponentsFormatter().string(from: $0)
                        } ?? "Guest")
                        Spacer()
                        Text(p.permission == .readWrite ? "Can Edit" : "View Only")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }

        Section(header: Text("Actions")) {
            Button {
                showSharePlanSheet = true
            } label: {
                Label("Invite Someone", systemImage: "square.and.arrow.up")
            }
            Button {
                showManageAccessSheet = true
            } label: {
                Label("Manage Access", systemImage: "person.2.badge.gearshape")
            }
            Button(role: .destructive) {
                showStopSharingAlert = true
            } label: {
                Label("Stop Sharing", systemImage: "xmark.circle")
            }
        }
    }

    // MARK: - Participant view

    private var participantSection: some View {
        Group {
            Section(header: Text("Joined plan")) {
                HStack {
                    Image(systemName: "person.fill").foregroundStyle(.blue)
                    Text(sharedPlan.ownerDisplayName ?? "Partner's plan")
                    Spacer()
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }

            Section {
                Button(role: .destructive) {
                    sharedPlan.clearAcceptedShare()
                    dismiss()
                } label: {
                    Label("Leave Shared Plan", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } footer: {
                Text("You'll lose access to the shared plan but keep your own meals.")
            }
        }
    }

    // MARK: - Not sharing view

    private var notSharingSection: some View {
        Section(
            footer: Text("Invite a partner or family member to view and edit this meal plan together.")
        ) {
            if coordinator.isLoading {
                HStack {
                    ProgressView().scaleEffect(0.8)
                    Text("Setting up…").foregroundStyle(.secondary)
                }
            } else {
                Button {
                    showSharePlanSheet = true
                } label: {
                    Label("Share Your Plan", systemImage: "square.and.arrow.up")
                }
            }
        }
    }
}
