//
//  MealSlotView.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 2/16/26.
//
import SwiftUI

struct MealSlotView: View {
    let title: String
    let meal: PlannedMeal?
    let expandUp: Bool
    
    var onTap: () -> Void
    var onSwitch: () -> Void
    var onDelete: () -> Void
    var onNotes: () -> Void
    var onCloseEmpty: (() -> Void)? = nil
    
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            
            ZStack(alignment: .topTrailing) {
                
                // 1. THE MAIN CLICKABLE CARD
                Button(action: onTap) {
                    ZStack(alignment: .bottomLeading) {
                        
                        // --- BACKGROUND LAYER ---
                        if let meal {
                            if let imageData = meal.recipe?.image, let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 80, maxHeight: .infinity)
                                    .clipped()
                                    .overlay(Color.black.opacity(0.3))
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(meal.isEatingOut ? Color.orange.opacity(0.2) : Color.blue.opacity(0.1))
                                    if meal.isEatingOut {
                                        Image(systemName: "fork.knife")
                                            .font(.system(size: 32, weight: .bold))
                                            .foregroundStyle(.white.opacity(0.8))
                                    }
                                }
                            }
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(uiColor: .secondarySystemBackground))
                        }
                        
                        // --- TEXT LAYER ---
                        if let meal {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(meal.displayTitle)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .lineLimit(2)
                                    .foregroundStyle(hasImage(meal) ? .white : .primary)
                                
                                HStack(spacing: 4) {
                                    if meal.isEatingOut {
                                        Image(systemName: "infinity")
                                    } else if let recipe = meal.recipe {
                                        Image(systemName: "clock")
                                        Text("\(recipe.prepTime.totalMinutes)m")
                                    }
                                }
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(hasImage(meal) ? .white.opacity(0.9) : .secondary)
                            }
                            .padding(8)
                        } else {
                            Image(systemName: "plus")
                                .font(.headline)
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        }
                    }
                    .frame(minHeight: 80, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                
                // 2. THE DELETE BUTTON (Only shows if a meal exists)
                if meal != nil {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.red)
                            .frame(width: 28, height: 28)
                    }
                    .padding(4)
                    
                } else if let onCloseEmpty = onCloseEmpty {
                    Button(action: onCloseEmpty) {
                        Image(systemName: expandUp ? "chevron.down" : "chevron.up")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(6)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding(6)
                }
            }
        }
    }
    
    private func hasImage(_ meal: PlannedMeal) -> Bool {
        return meal.recipe?.image != nil
    }
}

