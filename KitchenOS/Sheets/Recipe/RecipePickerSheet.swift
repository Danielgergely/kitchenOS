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
    
    var prefilledDate: Date? = nil
    var prefilledMealType: MealType? = nil
    
    var onSelectRecipe: (Recipe) -> Void
    var onSelectCustomMeal: (String, CookingType) -> Void
    
    @State private var selectedCookingType: CookingType = .homeCooked
    @State private var customMealTitle: String = ""
    @State private var searchText = ""
    @State private var showingRecommendation = false
        
    var filteredRecipes: [Recipe] {
        if searchText.isEmpty { return recipes }
        return recipes.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    CookingTypeSelector(selection: $selectedCookingType)
                        .padding(.vertical, 4)
                } header: {
                    Text("Meal Type")
                }
                
                if selectedCookingType == .homeCooked {
                    
                    Section {
                        Button {
                            showingRecommendation = true
                        } label: {
                            Label("Ask Chef AI for a Suggestion...", systemImage: "wand.and.stars")
                                .font(.headline)
                                .foregroundStyle(.blue)
                        }
                    }
                    
                    Section {
                        if filteredRecipes.isEmpty {
                            Text("No recipes found")
                        } else {
                            ForEach(filteredRecipes) { recipe in
                                Button {
                                    onSelectRecipe(recipe)
                                    dismiss()
                                } label: {
                                    HStack {
                                        if let data = recipe.image, let uiImage = UIImage(data: data) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
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
                    } header: {
                        Text("Select Recipe")
                    }
                } else {
                    Section {
                        TextField("What are you having?", text: $customMealTitle)
                    } header: {
                        Text("Meal Details")
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
                if selectedCookingType != .homeCooked {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            onSelectCustomMeal(customMealTitle, selectedCookingType)
                            dismiss()
                        }
                        .disabled(customMealTitle.isEmpty)
                    }
                }
            }
            .sheet(isPresented: $showingRecommendation) {
                RecommendationSheet(
                    prefilledDate: prefilledDate,
                    prefilledMealType: prefilledMealType
                ) { recipe in
                    onSelectRecipe(recipe)
                    showingRecommendation = false
                    dismiss()
                }
            }
        }
    }
}
