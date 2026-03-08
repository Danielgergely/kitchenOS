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
            GeometryReader { geo in
                let leftPannelWidth = min(max(geo.size.width * 0.35, 300.0), 300.0)
                // padding (48) + header height (~50) + row spacing (20)
                let availableHeight = geo.size.height - 120.0
                let contentHeight = max(availableHeight, 550.0)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        headerSection
                        
                        // Main Dashboard Layout
                        HStack(alignment: .top, spacing: 20) {
                            
                            // --- LEFT PANEL: DAILY PLAN ---
                            todayPanel
                                .frame(width: leftPannelWidth)
                            
                            // --- RIGHT PANEL: WIDGET GRID ---
                            Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                                
                                // Row 1: Two Small Widgets
                                GridRow {
                                    TotalRecipesWidget(recipeCount: allRecipes.count)
                                    ShoppingListWidget(items: pendingShoppingItems)
                                }
                                
                                // Row 2: Large Widget (Highest Rated)
                                GridRow {
                                    HighestRatedWidget(recipes: allRecipes)
                                        .gridCellColumns(2)
                                }
                                
                                // Row 3: Large Widget (Most Cooked)
                                GridRow {
                                    MostCookedWidget(recipes: allRecipes)
                                        .gridCellColumns(2)
                                }
                                
                                // Row 4: Large Widget (Habits Chart)
                                GridRow {
                                    CookingHabitsWidget(meals: allMeals)
                                        .gridCellColumns(2)
                                }
                            }
                            .frame(maxHeight: .infinity)
                        }
                        .frame(maxHeight: contentHeight)
                    }
                    .padding(24)
                }
                .background(Color(uiColor: .systemGroupedBackground))
                .navigationTitle("Dashboard")
                .navigationBarHidden(true)
            }
        }
    }
    
    private var headerSection: some View {
    HStack {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date().formatted(.dateTime.weekday(.wide).month().day()))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            Text("Good \(greeting), Chef")
                .font(.largeTitle.weight(.bold))
        }
        Spacer()
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
    
    private var todayPanel: some View {
        DashboardCard(color: .blue) {
            VStack(alignment: .leading, spacing: 20) {
                Label("Today's Plan", systemImage: "calendar.day.timeline.left")
                    .font(.title3.bold())
                    .foregroundStyle(.blue)
                
                let todaysMeals = allMeals.filter { Calendar.current.isDateInToday($0.day?.date ?? Date.distantPast) }
                
                if todaysMeals.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "plate")
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)
                        Text("Nothing planned for today.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 40)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(todaysMeals.sorted(by: { $0.type.rawValue > $1.type.rawValue })) { meal in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(meal.type.rawValue.capitalized)
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                
                                // Show Image if it's a recipe
                                if let data = meal.recipe?.image, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(maxHeight: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                
                                Text(meal.displayTitle)
                                    .font(.headline)
                            }
                            .padding(.bottom, 8)
                        }
                    }
                }
                Spacer()
            }
        }
    }
}
