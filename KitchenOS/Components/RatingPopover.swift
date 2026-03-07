//
//  RatingPopover.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/7/26.
//
import SwiftUI
import SwiftData

struct RatingPopover: View {
    @Bindable var meal: PlannedMeal
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Rate this Meal")
                .font(.headline)
            
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: (meal.ratingGiven ?? 0) >= star ? "star.fill" : "star")
                        .font(.title)
                        .foregroundStyle(.yellow)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring) {
                                meal.ratingGiven = star
                            }
                            // Dismiss smoothly after selection
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                dismiss()
                            }
                        }
                }
            }
        }
        .padding(24)
        .presentationCompactAdaptation(.popover)
    }
}
