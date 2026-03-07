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
                
                // --- RECIPE GRID ---
                LazyVGrid(columns: gridColumns, spacing: 16) {
                        AddPlaceholderSquare(title: "New Recipe", icon: "plus") {
                            isShowingAddRecipeSheet = true
                        }
                        .frame(height: 160)
                        
                        if let recipes = book.recipes {
                            ForEach(recipes) { recipe in
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
    }
}
