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
    @AppStorage(RecipeLanguage.storageKey) private var recipeLanguageRaw: String = RecipeLanguage.automatic.rawValue
    @AppStorage(AIProvider.storageKey) private var aiProviderRaw: String = AIProvider.automatic.rawValue
    @AppStorage(OllamaSettings.serverURLKey) private var ollamaServerURL: String = ""
    @AppStorage(OllamaSettings.modelKey) private var ollamaModel: String = OllamaSettings.defaultModel
    @State private var connectionStatus: ConnectionStatus?

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

                // --- AI ENGINE SECTION ---
                Section(header: Text("AI Engine"), footer: aiEngineFooter) {
                    Picker(selection: $aiProviderRaw) {
                        ForEach(AIProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider.rawValue)
                        }
                    } label: {
                        Label("Provider", systemImage: "cpu")
                    }

                    if aiProviderRaw == AIProvider.automatic.rawValue {
                        HStack {
                            Label("Apple Intelligence", systemImage: "apple.intelligence")
                            Spacer()
                            if let reason = OnDeviceModel.unavailableReason {
                                Text(reason).foregroundStyle(.secondary)
                            } else {
                                Label("Available", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .labelStyle(.titleAndIcon)
                            }
                        }
                    }

                    if aiProviderRaw != AIProvider.gemini.rawValue {
                        HStack {
                            Label("Server", systemImage: "desktopcomputer")
                            Spacer()
                            TextField(aiProviderRaw == AIProvider.automatic.rawValue ? "Optional" : "http://100.x.y.z:11434", text: $ollamaServerURL)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Label("Model", systemImage: "shippingbox")
                            Spacer()
                            TextField(OllamaSettings.defaultModel, text: $ollamaModel)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(.secondary)
                        }
                        Button {
                            Task { await testOllamaConnection() }
                        } label: {
                            HStack {
                                Label("Test Connection", systemImage: "antenna.radiowaves.left.and.right")
                                Spacer()
                                connectionStatusView
                            }
                        }
                        .disabled(connectionStatus == .checking)
                    }
                }
                .onChange(of: ollamaServerURL) { connectionStatus = nil }
                .onChange(of: ollamaModel) { connectionStatus = nil }

                // --- RECIPE EXTRACTION SECTION ---
                Section(
                    header: Text("Recipe Language"),
                    footer: Text("Recipes extracted from a URL or image are translated into this language so the whole recipe stays consistent.")
                ) {
                    Picker(selection: $recipeLanguageRaw) {
                        ForEach(RecipeLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang.rawValue)
                        }
                    } label: {
                        Label("Extraction Language", systemImage: "character.bubble")
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

    // MARK: - AI Engine

    enum ConnectionStatus: Equatable {
        case checking
        case ready
        case failed(String)
    }

    private func testOllamaConnection() async {
        connectionStatus = .checking
        do {
            let client = try OllamaClient.fromSettings()
            let installed = try await client.installedModels()
            connectionStatus = client.isModelInstalled(in: installed)
                ? .ready
                : .failed("Connected, but “\(client.model)” isn't installed. On the Mac run: ollama pull \(client.model)")
        } catch {
            connectionStatus = .failed(error.localizedDescription)
        }
    }

    @ViewBuilder
    private var connectionStatusView: some View {
        switch connectionStatus {
        case .checking:
            ProgressView().scaleEffect(0.8)
        case .ready:
            Label("Ready", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .labelStyle(.titleAndIcon)
        case .failed:
            Label("Failed", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
                .labelStyle(.titleAndIcon)
        case nil:
            EmptyView()
        }
    }

    @ViewBuilder
    private var aiEngineFooter: some View {
        if case .failed(let message) = connectionStatus {
            Text(message).foregroundStyle(.red)
        } else if aiProviderRaw == AIProvider.automatic.rawValue {
            Text("Free, and private by default. Photo imports use Apple's on-device model where the device supports Apple Intelligence; otherwise, or if it fails, your Mac if a server is entered, and finally simple text rules that work on every device, offline. Meal suggestions use your Mac if set, otherwise rules based on your preferences.")
        } else if aiProviderRaw == AIProvider.local.rawValue {
            Text("Photo and web imports and meal suggestions run on Ollama on your Mac, for free. The Mac must be awake and reachable from this device. Recommended: connect both devices with Tailscale and enter the Mac's Tailscale address here, e.g. http://100.x.y.z:11434. Ollama has no password, so don't expose it to shared Wi-Fi.")
        } else {
            Text("Uses Google's Gemini API, which is billed per request.")
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
