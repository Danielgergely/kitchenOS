//
//  RecipeBookDetailView.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 2/28/26.
//
import SwiftUI
import SwiftData

struct RecipeBookDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var book: RecipeBook
    
    @State private var isShowingEditSheet = false
    @State private var isShowingAddRecipeSheet = false
    
    @State private var searchText = ""
    @State private var selectedTags: [Tag] = []
    @State private var selectedFoodTypes: [FoodType] = []
        
    var filteredRecipes: [Recipe] {
        guard let recipes = book.recipes else { return [] }
        var result = recipes
        
        // 1. Text Search
        if !searchText.isEmpty {
            result = result.filter { recipe in
                recipe.summary.localizedCaseInsensitiveContains(searchText) ||
                recipe.title.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // 2. Food Type Filter
        if !selectedFoodTypes.isEmpty {
            result = result.filter { selectedFoodTypes.contains($0.type) }
        }
        
        // 3. Tag Filter
        if !selectedTags.isEmpty {
            result = result.filter { recipe in
                let recipeTagIds = recipe.tags.map { $0.id }
                return selectedTags.allSatisfy { selectedTag in
                    recipeTagIds.contains(selectedTag.id)
                }
            }
        }
        
        return result
    }
    
    let gridColumns = [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // --- HEADER IMAGE ---
                if let data = book.image, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .overlay {
                            LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                        }
                }
                
                // --- SEARCH BAR ---
                if !(book.recipes?.isEmpty ?? true) || !searchText.isEmpty {
                    HStack {
                        Spacer()
                        ExpandableSearchBar(
                            text: $searchText,
                            placeholder: "Search cookbook...",
                            selectedTags: $selectedTags,
                            selectedFoodTypes: $selectedFoodTypes
                        )
                    }
                    .padding(.horizontal)
                }
                
                // --- RECIPE GRID ---
                LazyVGrid(columns: gridColumns, spacing: 16) {
                        AddPlaceholderSquare(title: "New Recipe", icon: "plus") {
                            isShowingAddRecipeSheet = true
                        }
                        .frame(height: 160)
                        
                        ForEach(filteredRecipes) { recipe in
                            NavigationLink(value: recipe) {
                                RecipeSquare(recipe: recipe) {
                                    withAnimation(.spring()) {
                                        recipe.book = nil
                                    }
                                }
                                .frame(height: 160)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                if book.recipes?.isEmpty ?? true {
                    // Empty State
                    VStack(spacing: 16) {
                        Image(systemName: "text.book.closed")
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)
                        Text("This cookbook is empty.")
                            .font(.headline)
                        Text("Open a recipe and tap the bookmark icon to add it to '\(book.title)'.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                }
            }
        }
        .navigationTitle(book.title)
        .navigationSubtitle((book.recipes?.count.description ?? "0") + " Recipes")
        .navigationBarTitleDisplayMode(.large)
        .edgesIgnoringSafeArea(book.image != nil ? .top : [])
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    isShowingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $isShowingEditSheet) {
            RecipeBookEditorSheet(bookToEdit: book) {
                dismiss()
            }
        }
        .sheet(isPresented: $isShowingAddRecipeSheet) {
            RecipeEditorSheet(initialBook: book)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}
