//
//  RecipePickerSheet.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 2/19/26.
//
import SwiftUI
import SwiftData

struct RecipePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Recipe.title) private var recipes: [Recipe]
    
    var onSelectRecipe: (Recipe) -> Void
    var onSelectEatingOut: () -> Void
    
    @State private var searchText = ""
        
    var filteredRecipes: [Recipe] {
        if searchText.isEmpty { return recipes }
        return recipes.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Eating Out") {
                        onSelectEatingOut()
                        dismiss()
                    }
                    .foregroundStyle(.orange)
                }
                
                Section("My Recipes") {
                    if recipes.isEmpty {
                        Text("No recipes yet. Add some first!")
                            .foregroundStyle(.secondary)
                    }
                    
                    ForEach(filteredRecipes) { recipe in
                        Button {
                            onSelectRecipe(recipe)
                            dismiss()
                        } label: {
                            HStack {
                                if let data = recipe.image, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 40, height: 40)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                } else {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.secondary.opacity(0.2))
                                        .frame(width: 40, height: 40)
                                        .overlay {
                                            Image(systemName: "fork.knife").font(.caption).foregroundStyle(.secondary)
                                        }
                                }
                                
                                VStack(alignment: .leading) {
                                    Text(recipe.title).foregroundStyle(.primary)
                                    Text(recipe.type.rawValue).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search recipes...")
            .navigationTitle("Select Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
