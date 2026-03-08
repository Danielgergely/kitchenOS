//
//  CookingHabitsWidget.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/8/26.
//
import SwiftUI
import Charts

struct CookingHabitsWidget: View {
    let meals: [PlannedMeal]
    
    var body: some View {
        DashboardCard(color: .green) {
            VStack(alignment: .leading, spacing: 16) {
                Label("Cooking Habits", systemImage: "chart.pie.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                
                let completedMeals = meals.filter { $0.isCompleted }
                
                if completedMeals.isEmpty {
                    Text("No data yet. Complete some meals to see your habits!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxHeight: .infinity)
                } else {
                    Chart {
                        ForEach(CookingType.allCases, id: \.self) { type in
                            let count = completedMeals.filter { $0.cookingType == type }.count
                            if count > 0 {
                                SectorMark(
                                    angle: .value("Count", count),
                                    innerRadius: .ratio(0.6),
                                    angularInset: 2.0
                                )
                                .cornerRadius(4)
                                .foregroundStyle(by: .value("Type", type.rawValue))
                            }
                        }
                    }
                    .chartLegend(position: .trailing)
                    .frame(maxWidth: 250, maxHeight: .infinity)
                }
            }
            .frame(maxHeight: .infinity)
        }
    }
}
