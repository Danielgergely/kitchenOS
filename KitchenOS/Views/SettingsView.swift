//
//  SettingsView.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/1/26.
//
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage("isAdminMode") private var isAdminMode: Bool = false
    @State private var dummyAdminToggle: Bool = false
    
    @Environment(\.modelContext) private var modelContext
    @Query private var allRecipes: [Recipe]
    @Query private var allBooks: [RecipeBook]
    
    @State private var showingPreferencesSheet = false
    @State private var showingPasswordAlert = false
    @State private var adminPasswordInput = ""
    
    @AppStorage("remindersListName") private var remindersListName: String = "KitchenOS"
    
    var body: some View {
        NavigationStack {
            Form {
                // --- PERSONALIZATION SECTION ---
                Section(header: Text("Personalization"), footer: Text("Teach KitchenOS about your tastes to get better AI meal suggestions.")) {
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
                
                // --- ADMIN SECTION ---
                Section(header: Text("Developer")) {
                    Toggle(isOn: $dummyAdminToggle) {
                        Label("Admin Mode", systemImage: "person.badge.key.fill")
                    }
                    .onChange(of: dummyAdminToggle) { oldValue, newValue in
                        if newValue == true && isAdminMode == false {
                            showingPasswordAlert = true
                            dummyAdminToggle = false
                        } else if newValue == false {
                            isAdminMode = false
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingPreferencesSheet) {
                UserPreferencesSheet()
            }
            .onAppear {
                dummyAdminToggle = isAdminMode
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
}
