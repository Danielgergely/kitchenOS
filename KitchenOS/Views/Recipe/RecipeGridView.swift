//
//  RecipeGridView.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 2/17/26.
//
import SwiftUI
import SwiftData

struct RecipeGridView: View {
    @Query(sort: \Recipe.title) private var recipes: [Recipe]
    @State private var isShowingAddSheet = false
    
    let columns = [
        GridItem(.adaptive(minimum: 200), spacing: 20)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(recipes) { recipe in
                    NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                        RecipeCard(recipe: recipe)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle("Recipes")
        .toolbar {
            Button(action: { isShowingAddSheet = true }) {
                Label("Add Recipe", systemImage: "plus")
            }
        }
        .sheet(isPresented: $isShowingAddSheet) {
            RecipeEditorSheet()
        }
    }
}
