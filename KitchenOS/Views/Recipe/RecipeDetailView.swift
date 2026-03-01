//
//  RecipeDetailView.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 2/18/26.
//
import SwiftUI
import SwiftData

struct RecipeDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    
    @State private var isShowingEditSheet = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header image
                if let data = recipe.image, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 300)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(uiColor: .secondarySystemBackground))
                        .frame(height: 300)
                        .overlay {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 80))
                                .foregroundStyle(.tertiary)
                        }
                }
                // Content container
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(recipe.title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(recipe.summary)
                            .font(.body)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 16) {
                            Label("\(recipe.prepTime.totalMinutes) min", systemImage: "clock")
                            Label {
                                Text(recipe.type.info.name)
                            } icon: {
                                Image(recipe.type.info.icon)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                            }

                            Spacer()
                        }
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                        .padding(.top, 4)
                        
                        if !recipe.tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(recipe.tags) { tag in
                                        TagPill(tag: tag, isSelected: false)
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    
                    Divider()
                    
                    // Ingredients
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ingredients")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        if (recipe.ingredients.isEmpty) {
                            Text("No ingredients listed")
                                .foregroundStyle(.secondary)
                                .italic()
                        } else {
                            ForEach(recipe.ingredients) { ingredient in
                                HStack {
                                    Image(systemName: "circle")
                                        .foregroundStyle(.tertiary)
                                    Text(ingredient.name)
                                    Spacer()
                                    Text("\(ingredient.amount, format: .number) \(ingredient.unit.rawValue)")
                                    
                                }
                            }
                        }
                        
                    }
                    
                    Divider()
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Instructions")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        if (recipe.instructions.isEmpty) {
                            Text("No instructions provided.")
                                .foregroundStyle(.secondary)
                                .italic()
                        } else {
                            Text(recipe.instructions)
                                .lineSpacing(6)
                        }
                    }
                }
                .padding(24)
            }
        }
        .ignoresSafeArea(edges: .top)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    isShowingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $isShowingEditSheet) {
            RecipeEditorSheet(recipeToEdit: recipe)
        }
    }
}
