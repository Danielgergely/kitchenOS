//
//  SimpleRecipeSquare.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/21/26.
//
import SwiftUI

struct SimpleRecipeSquare: View {
    let preview: RecipePreview
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // --- 1. THE BACKGROUND IMAGE ---
            if let urlString = preview.imageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            Color(uiColor: .secondarySystemBackground)
                            ProgressView()
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                            .clipped()
                    case .failure:
                        fallbackBackground
                    @unknown default:
                        fallbackBackground
                    }
                }
            } else {
                fallbackBackground
            }
            
            // --- 2. THE DARKENING GRADIENT ---
            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .center,
                endPoint: .bottom
            )
            
            // --- 3. THE TEXT ---
            VStack(alignment: .leading, spacing: 4) {
                Text(preview.title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                
                HStack {
                    Label("\(preview.timeMinutes)m", systemImage: "clock")
                    Spacer()
                    Text(preview.category.capitalized)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Capsule())
                }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.9))
            }
            .padding(12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // A reusable fallback if the image fails to load or doesn't exist
    private var fallbackBackground: some View {
        ZStack {
            Color(uiColor: .secondarySystemBackground)
            Image(systemName: "fork.knife")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
