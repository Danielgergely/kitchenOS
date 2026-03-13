//
//  MostCookedWidget.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/8/26.
//
import SwiftUI

struct MostCookedWidget: View {
    let recipes: [Recipe]
    let size: WidgetSize
    
    var topRecipe: Recipe? {
        recipes.max(by: { $0.timesCooked < $1.timesCooked })
    }
    
    var body: some View {
        DashboardCard(color: .pink) {
            VStack(alignment: .leading, spacing: size == .small ? 8 : 12) {
                // MARK: Header
                HStack {
                    Label("Most Cooked", systemImage: "flame.fill")
                        .font(size == .small ? .caption2.bold() : .caption.bold())
                        .foregroundStyle(.pink)
                        .textCase(.uppercase)
                        .lineLimit(1)
                    Spacer()
                }
                
                // MARK: Content
                if let top = topRecipe, top.timesCooked > 0 {
                    if size == .medium {
                        HStack(spacing: 12) {
                            recipeImage(for: top)
                                .frame(width: 80)
                            recipeDetails(for: top)
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        recipeImage(for: top)
                        recipeDetails(for: top)
                    }
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func recipeImage(for recipe: Recipe) -> some View {
        if let data = recipe.image, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(minHeight: size == .small ? 40 : 60, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.pink.opacity(0.1))
                .frame(minHeight: size == .small ? 40 : 60, maxHeight: .infinity)
                .overlay {
                    Image(systemName: "fork.knife").foregroundStyle(.pink.opacity(0.5))
                }
        }
    }
    
    @ViewBuilder
    private func recipeDetails(for recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(recipe.title)
                .font(size == .small ? .subheadline.weight(.semibold) : .headline)
                .lineLimit(size == .small ? 1 : 2) // Tighter constraints for small widgets
                
            Text("Cooked \(recipe.timesCooked) times")
                .font(size == .small ? .caption2 : .caption)
                .foregroundStyle(.secondary)
        }
    }
    
    @ViewBuilder
    private var emptyState: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.pink.opacity(0.1))
            .frame(minHeight: 40, maxHeight: .infinity)
            .overlay {
                Image(systemName: "fork.knife").foregroundStyle(.pink.opacity(0.5))
            }
        
        Text("Cook more meals!")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
