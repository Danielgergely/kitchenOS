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
    let size: WidgetSize
    
    var body: some View {
        let completedMeals = meals.filter { $0.isCompleted }
        
        BaseWidgetLayout(
            size: size,
            color: .green,
            icon: "chart.pie.fill",
            title: "Cooking Habits",
            subtitle: completedMeals.isEmpty ? "Complete some meals!" : "Based on history"
        ) {
            // Main Content
            if !completedMeals.isEmpty {
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
                .chartLegend(size == .large ? .visible : .hidden)
            } else {
                Circle().stroke(Color.green.opacity(0.2), lineWidth: 4)
            }
        } extraStats: {
            EmptyView()
        }
    }
}
