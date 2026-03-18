//
//  RecipeDetailView.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 2/18/26.
//
import SwiftUI
import SwiftData

struct RecipeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let recipe: Recipe
    
    @State private var isShowingEditSheet = false
    @State private var isIngredientsExpanded: Bool = true
    @State private var animatingIngredientId: UUID? = nil
    
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
                    
                    RecipeStatsCard(recipe: recipe)
                    
                    Divider()
                    
                    // Ingredients
                    VStack(alignment: .leading, spacing: 16) {
                        DisclosureGroup(isExpanded: $isIngredientsExpanded) {
                            VStack(spacing: 20) {
                                // "Add All" functionality
                                Button {
                                    addAllToCart()
                                } label: {
                                    Label("Add All to Shopping List", systemImage: "cart.badge.plus")
                                        .font(.subheadline.bold())
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.blue.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 8)

                                // The Grid we built earlier
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 16)], spacing: 12) {
                                    ForEach(recipe.ingredients) { ingredient in
                                        ingredientCard(for: ingredient)
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text("Ingredients")
                                    .font(.title2.bold())
                                    .foregroundStyle(.primary)
                                
                                Spacer()
                                
                                Text("\(recipe.ingredients.count) items")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground).opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    Divider()
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Instructions")
                            .font(.title2.bold())
                        
                        if recipe.instructions.isEmpty {
                            ContentUnavailableView("No Instructions", systemImage: "text.badge.plus", description: Text("Tap Edit to add step-by-step instructions."))
                        } else {
                            let steps = recipe.instructions.components(separatedBy: .newlines)
                                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                            
                            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 16) {
                                    // Step Number Circle
                                    Text("\(index + 1)")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.white)
                                        .frame(width: 28, height: 28)
                                        .background(Color.blue, in: Circle())
                                    
                                    // Step Content
                                    Text(step)
                                        .font(.body)
                                        .lineSpacing(6)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(uiColor: .secondarySystemBackground).opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
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
            RecipeEditorSheet(recipeToEdit: recipe) {
                dismiss()
            }
        }
    }
    
    @ViewBuilder
    private func ingredientCard(for ingredient: Ingredient) -> some View {
        let isAdded = animatingIngredientId == ingredient.id
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(ingredient.name)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .lineLimit(1)
                Text("\(ingredient.amount, format: .number) \(ingredient.unit.rawValue)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                addToCart(ingredient)
            } label: {
                Image(systemName: isAdded ? "checkmark" : "cart.badge.plus")
                    .font(.title3)
                    .foregroundStyle(isAdded ? .white : .blue)
                    .padding(10)
                    .background(isAdded ? Color.green : Color.blue.opacity(0.1))
                    .clipShape(Circle())
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .overlay(alignment: .top) {
                if isAdded {
                    Text("+1")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .clipShape(Capsule())
                        .offset(y: -35)
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .move(edge: .bottom)).combined(with: .opacity),
                            removal: .opacity.combined(with: .move(edge: .top))
                        ))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .systemBackground))
        )
        .zIndex(isAdded ? 1 : 0)
    }

    private func addAllToCart() {
        withAnimation(.spring()) {
            for ingredient in recipe.ingredients {
                let newItem = ShoppingItem(
                    name: ingredient.name,
                    amount: ingredient.amount,
                    unit: ingredient.unit
                )
                modelContext.insert(newItem)
            }
            HapticManager.impact(style: .light)
        }
    }
    
    private func addToCart(_ ingredient: Ingredient) {
        let newItem = ShoppingItem(
            name: ingredient.name,
            amount: ingredient.amount,
            unit: ingredient.unit
        )
        modelContext.insert(newItem)
        
        withAnimation(.spring()) {
            animatingIngredientId = ingredient.id
        }
        
        // Clear the animation state
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            animatingIngredientId = nil
        }
    }
}
