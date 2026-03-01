//
//  RecipeLibararyView.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 2/28/26.
//
import SwiftUI
import SwiftData

struct RecipeLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \RecipeBook.title) private var books: [RecipeBook]
    @Query(sort: \Recipe.title) private var allRecipes: [Recipe]
    
    @State private var showingAddBookSheet = false
    @State private var showingAddRecipeSheet = false
    
    @State private var isBooksExpanded = true
    @State private var isRecipesExpanded = true
    
    let gridColumns = [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Recipe Books
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    isBooksExpanded.toggle()
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Text("My Cookbooks")
                                        .font(.title2.bold())
                                        .foregroundStyle(.primary)
                                    
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.tertiary)
                                        .rotationEffect(.degrees(isBooksExpanded ? 0 : -90))
                                }
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                            
                            Button {
                                print("Search Cookbook Tapped")
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                        
                        if isBooksExpanded {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    AddPlaceholderSquare(title: "New Cookbook", icon: "folder.badge.plus") {
                                        showingAddBookSheet = true
                                    }
                                    .frame(width: 160, height: 160)
                                    .frame(maxWidth: .infinity)
                                    
                                    ForEach(books) { book in
                                        NavigationLink(value: book) {
                                            RecipeBookSquare(book: book)
                                                .frame(width: 160, height: 160)
                                        }
                                        .dropDestination(for: String.self) { droppedStrings, location in
                                            // Get the ID string we just dragged
                                            guard let recipeIdString = droppedStrings.first,
                                                  let recipeId = UUID(uuidString: recipeIdString),
                                                  // Find the actual recipe in our array that matches this ID
                                                  let recipeToMove = allRecipes.first(where: { $0.id == recipeId }) else {
                                                return false
                                            }
                                            
                                            withAnimation {
                                                recipeToMove.book = book
                                            }
                                            
                                            return true
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                
                    // All Recipes
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    isRecipesExpanded.toggle()
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Text("All Recipes")
                                        .font(.title2.bold())
                                        .foregroundStyle(.primary)
                                    
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.tertiary)
                                        .rotationEffect(.degrees(isRecipesExpanded ? 0 : -90))
                                }
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                            
                            Button {
                                print("Search Recipes Tapped")
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                        
                        if isRecipesExpanded {
                            LazyVGrid(columns: gridColumns, spacing: 16) {
                                AddPlaceholderSquare(title: "New Recipe", icon: "plus") {
                                    showingAddRecipeSheet = true
                                }
                                .frame(height: 160)
                                
                                ForEach(allRecipes) { recipe in
                                    NavigationLink(value: recipe) {
                                        RecipeSquare(recipe: recipe)
                                            .frame(height: 160)
                                    }
                                    .draggable(recipe.id.uuidString) {
                                        RecipeSquare(recipe: recipe)
                                            .frame(width: 160, height: 160)
                                            .opacity(0.8)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
                .padding(.top)
            }
            .navigationDestination(for: RecipeBook.self) { book in
                RecipeBookDetailView(book: book)
            }
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe)
            }
            .navigationTitle("Recipes")
            .sheet(isPresented: $showingAddBookSheet) {
                RecipeBookEditorSheet()
            }
            .sheet(isPresented: $showingAddRecipeSheet) {
                RecipeEditorSheet()
            }
            
        }
    }
}
