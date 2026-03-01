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
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Data Management"), footer: Text("Export your entire recipe library as a JSON file to share with others, or import an existing backup.")) {
                    
                    // --- EXPORT BUTTON ---. I dont
                    // 1. We generate the file URL.
                    // 2. We pass it to the native Apple ShareLink.
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
                    
                    // --- IMPORT BUTTON ---
                    Button {
                        showingFileImporter = true
                    } label: {
                        Label("Import Recipes", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                // Pre-generate the export file as soon as the view loads
                exportFileURL = DataExchangeService.generateExportFile(from: allRecipes, books: allBooks)
            }
            // The native Apple file picker
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
        }
    }
}
