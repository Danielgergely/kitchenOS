//
//  SharedPlanSheet.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 5/19/26.
//

import SwiftUI

struct SharedPlanSheet: View {
    @Environment(SharedPlanService.self) private var sharedPlan
    @Environment(\.dismiss) private var dismiss

    let weekDates: [Date]

    var body: some View {
        NavigationStack {
            Group {
                if sharedPlan.isLoading {
                    ProgressView("Loading shared plan…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = sharedPlan.error {
                    ContentUnavailableView(
                        "Couldn't load shared plan",
                        systemImage: "exclamationmark.icloud",
                        description: Text(err)
                    )
                } else if sharedPlan.meals.isEmpty {
                    ContentUnavailableView(
                        "No shared meals yet",
                        systemImage: "calendar.badge.plus",
                        description: Text("The shared week plan is empty. Ask your household partner to add meals.")
                    )
                } else {
                    List {
                        ForEach(weekDates, id: \.self) { date in
                            let dayMeals = mealsFor(date: date)
                            if !dayMeals.isEmpty {
                                Section(header: Text(date, style: .date)) {
                                    ForEach(dayMeals) { meal in
                                        SharedMealRow(meal: meal)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Shared Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            await sharedPlan.fetchMeals(for: weekDates, isOwner: false)
        }
    }

    private static let mealOrder: [MealType] = [.breakfast, .lunch, .dinner, .snack]

    private func mealsFor(date: Date) -> [SharedMealEntry] {
        sharedPlan.meals.filter {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }
        .sorted {
            let a = Self.mealOrder.firstIndex(of: $0.mealType) ?? 99
            let b = Self.mealOrder.firstIndex(of: $1.mealType) ?? 99
            return a < b
        }
    }
}

private struct SharedMealRow: View {
    let meal: SharedMealEntry

    private var mealIcon: String {
        switch meal.mealType {
        case .breakfast: return "sun.horizon"
        case .lunch: return "fork.knife"
        case .dinner: return "moon.stars"
        case .snack: return "apple.logo"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: mealIcon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(meal.recipeTitle ?? meal.mealType.rawValue.capitalized)
                    .font(.body)
                if !meal.notes.isEmpty {
                    Text(meal.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(meal.mealType.rawValue.capitalized)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
