//
//  RecipeBookSquare.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 2/28/26.
//
import SwiftUI

struct RecipeBookSquare: View {
    let book: RecipeBook
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let data = book.image, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
            } else {
                Color.orange.opacity(0.8)
                Image(systemName: book.icon)
                    .font(.system(size: 50))
                    .foregroundStyle(.white.opacity(0.3))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("\(book.recipes?.count ?? 0) recipes")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
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
}
