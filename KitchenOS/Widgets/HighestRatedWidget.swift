//
//  HighestRatedWidget.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/8/26.
//
import SwiftUI

struct HighestRatedWidget: View {
    let recipes: [Recipe]
    
    var topRecipe: Recipe? {
        recipes.filter { $0.averageRating != nil }
            .max(by: { ($0.averageRating ?? 0) < ($1.averageRating ?? 0) })
    }
    
    var body: some View {
        DashboardCard(color: .yellow) {
            HStack(spacing: 16) {
                if let data = topRecipe?.image, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100) // Fixed elegant size
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.yellow.opacity(0.2))
                        .frame(width: 100, height: 100)
                        .overlay {
                            Image(systemName: "star.fill").font(.title2).foregroundStyle(.yellow)
                        }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Label("Highest Rated", systemImage: "star.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.yellow)
                        .textCase(.uppercase)
                    
                    Text(topRecipe?.title ?? "No Rated Recipes")
                        .font(.headline)
                        .lineLimit(2)
                    
                    Spacer() // Pushes the rating to the bottom
                    
                    if let rating = topRecipe?.averageRating {
                        HStack(spacing: 2) {
                            ForEach(0..<Int(rating.rounded()), id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.yellow)
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxHeight: .infinity)
        }
    }
}
