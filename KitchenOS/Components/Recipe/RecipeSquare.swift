//
//  RecipeSquare.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 2/28/26.
//
import SwiftUI

struct RecipeSquare: View {
    let recipe: Recipe
    
    var onRemove: (() -> Void)? = nil
    
    @State private var showingRemoveConfirmation = false
    @State private var showingPlanner = false
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // image background
            if let data = recipe.image, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
            } else {
                Color(uiColor: .secondarySystemBackground)
                Image(systemName: "fork.knife")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Infos background
            LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)
            
            // Text block
            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                
                // Rating
                if let rating = recipe.averageRating {
                    let stars = Int(rating.rounded())
                    HStack(spacing: 2) {
                        ForEach(0..<stars, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                        }
                    }
                    .padding(.bottom, 2)
                }
                
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
                .foregroundStyle(.white.opacity(0.9))
            }
            .padding(12)
        }
        .overlay(alignment: .topTrailing) {
            // inside a cook book
            if onRemove != nil {
                Button {
                    showingRemoveConfirmation = true
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.title2)
                        .foregroundStyle(.red, .red)
                        .shadow(radius: 2)
                        .padding(8)
                }
                .buttonStyle(.plain)
            } else if recipe.book != nil {
                Image("cooking.book")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(.white)
                    .padding(8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .contextMenu {
            Button {
                showingPlanner = true
            } label: {
                Label("Plan Meal...", systemImage: "calendar.badge.plus")
            }
        }
        .sheet(isPresented: $showingPlanner) {
            MealPlannerSheet(recipe: recipe)
        }
        .confirmationDialog("Remove recipe from Cookbook?", isPresented: $showingRemoveConfirmation, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                onRemove?()
            }
            Button("Cancel", role: .cancel) { }
        } message:  {
            let bookTitle = recipe.book?.title ?? "this cookbook"
            let message = "This will remove recipe \(recipe.title) from \(bookTitle) but it will stay in your main library."
            Text(message)
        }
    }
}

