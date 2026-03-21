//
//  TodayWidget.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/8/26.
//
import SwiftUI

struct TodayWidget: View {
    let meals: [PlannedMeal]
    let isLandscape: Bool
    
    var body: some View {
        DashboardCard(color: .blue) {
            VStack(alignment: .leading, spacing: 16) {
                
                // --- Header ---
                HStack {
                    Label("Today's Plan", systemImage: "calendar.day.timeline.left")
                        .font(.title3.bold())
                        .foregroundStyle(.blue)
                    Spacer()
                    Text(Date().formatted(.dateTime.weekday().day()))
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                }
                
                let todaysMeals = meals.filter { Calendar.current.isDateInToday($0.day.date) }
                
                // --- Content ---
                if todaysMeals.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.tertiary)
                        Text("Nothing planned for today.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    let mealLayout = isLandscape ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16)) : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
                    
                    mealLayout {
                        ForEach(todaysMeals.sorted(by: { $0.type.rawValue > $1.type.rawValue })) { meal in
                            
                            // Individual Meal Item
                            VStack(alignment: .leading, spacing: 8) {
                                Text(meal.type.rawValue.capitalized)
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                
                                let leftoverImageData = getLeftoverImage(for: meal)
                                
                                if let data = meal.recipe?.image ?? leftoverImageData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(minWidth: 60, maxWidth: .infinity, minHeight: 40, maxHeight: .infinity)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .opacity(meal.cookingType == .leftovers ? 0.3 : 1.0)
                                } else {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.blue.opacity(0.1))
                                        .frame(minWidth: 60, maxWidth: .infinity, minHeight: 40, maxHeight: .infinity)
                                        .overlay {
                                            Image(systemName: "fork.knife").foregroundStyle(.blue.opacity(0.5))
                                        }
                                }
                                
                                Text(meal.displayTitle)
                                    .font(.headline)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                    }
                    .frame(maxHeight: .infinity)
                }                
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
    
    private func getLeftoverImage(for meal: PlannedMeal) -> Data? {
        guard meal.cookingType == .leftovers else { return nil }
        
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: meal.day.date) ?? Date()
        
        // Find all meals from yesterday
        let yesterdaysMeals = meals.filter { Calendar.current.isDate($0.day.date, inSameDayAs: yesterday) }
        
        // Try to grab dinner first, otherwise fallback to lunch
        if let dinnerImg = yesterdaysMeals.first(where: { $0.type == .dinner })?.recipe?.image {
            return dinnerImg
        }
        if let lunchImg = yesterdaysMeals.first(where: { $0.type == .lunch })?.recipe?.image {
            return lunchImg
        }
        
        return nil
    }
}
