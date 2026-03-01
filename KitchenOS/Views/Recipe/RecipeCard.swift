//
//  RecipeCard.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 2/17/26.
//
import SwiftUI

struct RecipeCard: View {
    let recipe: Recipe
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                if let data = recipe.image, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 130)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(uiColor: .secondarySystemBackground))
                        .frame(height: 130)
                        .overlay {
                            Image(systemName: "fork.knife")
                                .font(.largeTitle)
                                .foregroundStyle(.quaternary)
                        }
                }
            }
            .frame(height: 160)
            .padding(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)
                
                HStack  {
                    Label("\(recipe.prepTime.totalMinutes) min", systemImage: "clock")
                    
                    Spacer()
                    
                    Text(recipe.type.rawValue)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color(uiColor: .tertiarySystemFill))
                        .clipShape(Capsule())
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(12)
        }
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 5, x: 0, y: 2)
    }
}
