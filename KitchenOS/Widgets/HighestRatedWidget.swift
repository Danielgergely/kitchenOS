//
//  HighestRatedWidget.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/8/26.
//
import SwiftUI

struct HighestRatedWidget: View {
    let recipes: [Recipe]
    let size: WidgetSize
    
    var topRecipe: Recipe? {
        recipes.filter { $0.averageRating != nil }
            .max(by: { ($0.averageRating ?? 0) < ($1.averageRating ?? 0) })
    }
    
    var body: some View {
        BaseWidgetLayout(
            size: size,
            color: .yellow,
            icon: "star.fill",
            title: "Highest Rated",
            subtitle: topRecipe != nil ? nil : "No Rated Recipes"
        ) {
            // Main Content
            if let data = topRecipe?.image, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.yellow.opacity(0.2))
                    .overlay {
                        Image(systemName: "star.fill").font(.title).foregroundStyle(.yellow)
                    }
            }
        } extraStats: {
            // Extra Stats
            if let recipe = topRecipe {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.title)
                        .font(size == .large ? .title2.bold() : .headline)
                        .lineLimit(size == .small ? 1 : 2)
                    
                    if let rating = recipe.averageRating {
                        HStack(spacing: 2) {
                            ForEach(0..<Int(rating.rounded()), id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(size == .large ? .subheadline : .caption2)
                                    .foregroundStyle(.yellow)
                            }
                        }
                    }
                    
                    // The extra details ONLY show if it's a .large widget
                    if size == .large {
                        Spacer()
                        Divider()
                        HStack {
                            Label("\(recipe.prepTime.totalMinutes)m", systemImage: "clock")
                            Spacer()
                            Label("\(recipe.ingredients.count) items", systemImage: "takeoutbag.and.cup.and.straw")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    }
                }
            }
        }
    }
}
