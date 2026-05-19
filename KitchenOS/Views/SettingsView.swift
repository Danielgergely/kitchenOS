//
//  SettingsView.swift
//  MealOS
//
//  Created by Daniel Gergely on 3/1/26.
//
import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import CloudKit

struct SettingsView: View {
    @AppStorage("isAdminMode") private var isAdminMode: Bool = false
    @State private var dummyAdminToggle: Bool = false

    @Environment(\.modelContext) private var modelContext
    @Query private var allRecipes: [Recipe]
    @Query private var allBooks: [RecipeBook]

    @State private var showingPreferencesSheet = false
    @State private var showingPasswordAlert = false
    @State private var adminPasswordInput = ""

    @AppStorage("remindersListName") private var remindersListName: String = "MealOS"

    private let sharing: CloudKitSharingCoordinator = .shared

    var body: some View {
        NavigationStack {
            Form {
                // --- ICLOUD ACCOUNT SECTION ---
                // Note on "Sign in with Apple": not used here because CloudKit IS the identity
                // system. Your iCloud account (Apple ID) authenticates you automatically —
                // there's no separate login needed, just like in the Notes or Calendar apps.
                // What the user controls is whether iCloud sync is active or not.
                Section(
                    header: Text("iCloud Account"),
                    footer: iCloudFooter
                ) {
                    HStack {
                        Label("Status", systemImage: "person.icloud")
                        Spacer()
                        iCloudStatusBadge
                    }

                    if sharing.iCloudStatus == .noAccount || sharing.iCloudStatus == .restricted {
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Label("Open Settings to Sign In", systemImage: "arrow.up.right.square")
                        }
                    }
                }
                .onAppear { Task { await sharing.checkAccountStatus() } }

                // --- PERSONALIZATION SECTION ---
                Section(header: Text("Personalization"), footer: Text("Teach MealOS about your tastes to get better AI meal suggestions.")) {
                    Button {
                        showingPreferencesSheet = true
                    } label: {
                        Label("Taste Profile & Preferences", systemImage: "person.crop.circle.badge.questionmark")
                            .foregroundStyle(.primary)
                    }
                }

                // --- INTEGRATIONS SECTION ---
                Section(header: Text("Integrations")) {
                    HStack {
                        Image(systemName: "list.bullet.rectangle.portrait")
                            .foregroundStyle(.blue)
                        Text("Reminders List")
                        Spacer()
                        TextField("List Name", text: $remindersListName)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                    }
                }

                // --- DEVELOPER SECTION ---
                Section(header: Text("Developer")) {
                    Toggle(isOn: $dummyAdminToggle) {
                        Label("Admin Mode", systemImage: "person.badge.key.fill")
                    }
                    .onChange(of: dummyAdminToggle) { _, newValue in
                        if newValue && !isAdminMode {
                            showingPasswordAlert = true
                            dummyAdminToggle = false
                        } else if !newValue {
                            isAdminMode = false
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                dummyAdminToggle = isAdminMode
            }

            // MARK: - Sheets & Alerts

            .sheet(isPresented: $showingPreferencesSheet) {
                UserPreferencesSheet()
            }

            .alert("Admin Access", isPresented: $showingPasswordAlert) {
                SecureField("Enter Password", text: $adminPasswordInput)
                Button("Cancel", role: .cancel) {
                    adminPasswordInput = ""
                    dummyAdminToggle = isAdminMode
                }
                Button("Verify") {
                    if adminPasswordInput == Secrets.adminPassword {
                        isAdminMode = true
                        dummyAdminToggle = true
                    }
                    adminPasswordInput = ""
                }
            } message: {
                Text("Please enter the developer password to enable publishing tools.")
            }
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var iCloudStatusBadge: some View {
        switch sharing.iCloudStatus {
        case .available:
            Label("Signed In", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .labelStyle(.titleAndIcon)
        case .noAccount:
            Label("Not Signed In", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
                .labelStyle(.titleAndIcon)
        case .restricted:
            Label("Restricted", systemImage: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
                .labelStyle(.titleAndIcon)
        case .temporarilyUnavailable:
            Label("Temporarily Unavailable", systemImage: "clock.badge.exclamationmark")
                .foregroundStyle(.orange)
                .labelStyle(.titleAndIcon)
        default:
            HStack(spacing: 6) {
                ProgressView().scaleEffect(0.8)
                Text("Checking…").foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var iCloudFooter: some View {
        switch sharing.iCloudStatus {
        case .available:
            Text("Your data syncs automatically across all your devices via your Apple ID. To sign out, go to Settings → Apple ID.")
        case .noAccount:
            Text("Sign in to iCloud to sync your meal plan across devices and share it with others.")
        default:
            Text("MealOS uses your iCloud account (Apple ID) for sync and sharing — no separate login needed.")
        }
    }
}
