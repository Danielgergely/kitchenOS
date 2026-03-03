//
//  DashboardView.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/3/26.
//
import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    
    // Fetching data to compute stats
    @Query private var allRecipes: [Recipe]
    @Query private var allMeals: [PlannedMeal]
    @Query(filter: #Predicate<ShoppingItem> { $0.isChecked == false })
    private var pendingShoppingItems: [ShoppingItem]
    
    // Grid layout that automatically adjusts based on screen width
    let columns = [GridItem(.adaptive(minimum: 320), spacing: 20)]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    
                    LazyVGrid(columns: columns, spacing: 20) {
                        todayCard
                        shoppingCard
                        topRecipeCard
                        habitsChartCard
                    }
                }
                .padding(24)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Dashboard")
            .navigationBarHidden(true) // We use our custom header instead
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date().formatted(.dateTime.weekday(.wide).month().day()))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            Text("Good \(greeting), Chef")
                .font(.largeTitle.weight(.bold))
        }
        .padding(.bottom, 8)
    }
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Morning"
        case 12..<17: return "Afternoon"
        default: return "Evening"
        }
    }
    
    // MARK: - Cards
    
    private var todayCard: some View {
        DashboardCard(color: .blue) {
            VStack(alignment: .leading, spacing: 16) {
                Label("Today's Plan", systemImage: "calendar.day.timeline.left")
                    .font(.headline)
                    .foregroundStyle(.blue)
                
                let todaysMeals = allMeals.filter { Calendar.current.isDateInToday($0.day?.date ?? Date.distantPast) }
                
                if todaysMeals.isEmpty {
                    Text("Nothing planned for today.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(todaysMeals.sorted(by: { $0.type.rawValue > $1.type.rawValue })) { meal in
                            HStack {
                                Text(meal.type.rawValue.capitalized)
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 70, alignment: .leading)
                                
                                Text(meal.displayTitle)
                                    .font(.subheadline.weight(.medium))
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var shoppingCard: some View {
        DashboardCard(color: .orange) {
            VStack(alignment: .leading, spacing: 16) {
                Label("Shopping List", systemImage: "cart")
                    .font(.headline)
                    .foregroundStyle(.orange)
                
                HStack(alignment: .firstTextBaseline) {
                    Text("\(pendingShoppingItems.count)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    Text("items to buy")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                if !pendingShoppingItems.isEmpty {
                    Text("Don't forget: \(pendingShoppingItems.prefix(2).map { $0.name }.joined(separator: ", "))\(pendingShoppingItems.count > 2 ? "..." : "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
    
    private var topRecipeCard: some View {
        DashboardCard(color: .pink) {
            VStack(alignment: .leading, spacing: 16) {
                Label("Most Cooked", systemImage: "flame.fill")
                    .font(.headline)
                    .foregroundStyle(.pink)
                
                if let topRecipe = allRecipes.max(by: { $0.timesCooked < $1.timesCooked }), topRecipe.timesCooked > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(topRecipe.title)
                            .font(.title3.weight(.bold))
                            .lineLimit(1)
                        
                        Text("Cooked \(topRecipe.timesCooked) times")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        if let rating = topRecipe.averageRating {
                            HStack(spacing: 2) {
                                ForEach(0..<Int(rating.rounded()), id: \.self) { _ in
                                    Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                } else {
                    Text("Cook more meals to see your favorites here!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var habitsChartCard: some View {
        DashboardCard(color: .green) {
            VStack(alignment: .leading, spacing: 16) {
                Label("Cooking Habits", systemImage: "chart.pie.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                
                let completedMeals = allMeals.filter { $0.isCompleted }
                if completedMeals.isEmpty {
                    Text("No data yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    // Simple chart showing home cooked vs eating out vs leftovers
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
                    .frame(height: 120)
                }
            }
        }
    }
}
