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
    
    @State private var exportFileURL: URL?
    @State private var showingFileImporter = false
    @State private var showingPreferencesSheet = false // Controls our new profile sheet
    
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
                
                // --- DATA MANAGEMENT SECTION ---
                Section(header: Text("Data Management"), footer: Text("Export your entire recipe library as a JSON file to share with others, or import an existing backup.")) {
                    
                    if let fileURL = exportFileURL {
                        ShareLink(item: fileURL) {
                            Label("Export Recipes (\(allRecipes.count))", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button {
                            // Generate the file when the user enters the settings view
                            exportFileURL = DataExchangeService.generateExportFile(from: allRecipes, books: allBooks)
                        } label: {
                            Label("Prepare Export File", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    
                    Button {
                        showingFileImporter = true
                    } label: {
                        Label("Import Recipes", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                exportFileURL = DataExchangeService.generateExportFile(from: allRecipes, books: allBooks)
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        DataExchangeService.importRecipes(from: url, context: modelContext)
                    }
                case .failure(let error):
                    print("Error selecting file: \(error.localizedDescription)")
                }
            }
            .sheet(isPresented: $showingPreferencesSheet) {
                UserPreferencesSheet()
            }
        }
    }
}
