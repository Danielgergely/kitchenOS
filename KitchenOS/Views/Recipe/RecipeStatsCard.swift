//
//  RecipeStatsCard.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/3/26.
//
import SwiftUI

struct RecipeStatsCard: View {
    let recipe: Recipe
    
    var body: some View {
        HStack(spacing: 20) {
            // 1. Average Rating Stat
            StatItem(
                icon: "star.fill",
                color: .yellow,
                value: formattedRating,
                label: "Average Rating"
            )
            
            Divider()
                .frame(height: 40)
            
            // 2. Times Cooked Stat
            StatItem(
                icon: "flame.fill",
                color: .orange,
                value: "\(recipe.timesCooked)",
                label: "Times Cooked"
            )
            
            Divider()
                .frame(height: 40)
            
            // 3. Last Cooked Stat
            StatItem(
                icon: "calendar.badge.clock",
                color: .blue,
                value: formattedDate,
                label: "Last Cooked"
            )
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var formattedRating: String {
        if let rating = recipe.averageRating {
            return String(format: "%.1f", rating)
        } else {
            return "-"
        }
    }
    
    private var formattedDate: String {
        guard let date = recipe.lastCookedDate else { return "Never" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Subcomponent for individual stats
private struct StatItem: View {
    let icon: String
    let color: Color
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.title3)
                
                Text(value)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
            }
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
