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
    @Environment(\.modelContext) private var modelContext
    @Query private var allRecipes: [Recipe]
    @Query private var allBooks: [RecipeBook]
    
    @State private var showingPreferencesSheet = false
    
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
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingPreferencesSheet) {
                UserPreferencesSheet()
            }
        }
    }
}
