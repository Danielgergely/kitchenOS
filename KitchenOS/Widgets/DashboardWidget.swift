//
//  DashboardWidget.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/13/26.
//
enum DashboardWidget: String, CaseIterable, Identifiable, Codable {
    case mostCooked = "Most Cooked"
    case highestRated = "Highest Rated"
    case habits = "Cooking Habits"
    case shopping = "Shopping List"
    case totalRecipes = "Total Recipes"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .mostCooked: return "flame.fill"
        case .highestRated: return "star.fill"
        case .habits: return "chart.pie.fill"
        case .shopping: return "cart"
        case .totalRecipes: return "book.pages.fill"
        }
    }
}
