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
        
        let stats: [(type: CookingType, count: Int)] = CookingType.allCases.map { type in
            (type: type, count: completedMeals.filter { $0.cookingType == type }.count)
        }
        .filter { $0.count > 0 }
        .sorted { $0.count > $1.count }
        
        BaseWidgetLayout(
            size: size,
            color: .green,
            icon: "chart.pie.fill",
            title: "Cooking Habits",
            subtitle: completedMeals.isEmpty ? "Complete some meals!" : "Based on history"
        ) {
            // MARK: - Main Content
            if !completedMeals.isEmpty {
                Chart {
                    ForEach(stats, id: \.type) { stat in
                        SectorMark(
                            angle: .value("Count", stat.count),
                            innerRadius: .ratio(0.6),
                            angularInset: 2.0
                        )
                        .cornerRadius(4)
                        .foregroundStyle(stat.type.color)
                        
                        .annotation(position: .overlay) {
                            if size != .small && stat.count > 0 {
                                Text("\(stat.count)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .shadow(radius: 2)
                            }
                        }
                    }
                }
                .chartLegend(.hidden)
            } else {
                Circle().stroke(Color.green.opacity(0.2), lineWidth: 4)
            }
        } extraStats: {
            // MARK: - Extra Stats (Custom Legend)
            if !stats.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    let displayCount = size == .small ? 2 : 4
                    ForEach(stats.prefix(displayCount), id: \.type) { stat in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(stat.type.color)
                                .frame(width: 8, height: 8)
                            
                            Text("\(stat.count) \(stat.type.rawValue.replacingOccurrences(of: " Meal", with: ""))")
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                }
                .font(size == .large ? .subheadline : .caption)
                .foregroundStyle(.secondary)
            } else {
                EmptyView()
            }
        }
    }
}
