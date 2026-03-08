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
    
    @Query private var allRecipes: [Recipe]
    @Query private var allMeals: [PlannedMeal]
    @Query(filter: #Predicate<ShoppingItem> { $0.isChecked == false })
    private var pendingShoppingItems: [ShoppingItem]
    var isSidebarOpen: Bool
    
    @State private var sidebarWidth: CGFloat = 320.0
    
    let columns = [
        GridItem(.adaptive(minimum: 140, maximum: .infinity), spacing: 16)
    ]
    
    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height            
            let spacing: CGFloat = 16
            
            let masterLayout = isLandscape ? AnyLayout(HStackLayout(spacing: spacing)) : AnyLayout(VStackLayout(spacing: spacing))
            
            masterLayout {
                TodayWidget(meals: allMeals, isLandscape: isLandscape)
                    .frame(
                        width: isLandscape ? (geo.size.width - spacing) * 0.4 : nil,
                        height: isLandscape ? nil : (geo.size.height - spacing) * 0.4
                    )
                
                VStack(spacing: spacing) {
                    ForEach(0..<3, id: \.self) { row in
                        HStack(spacing: spacing) {
                            ForEach(0..<3, id: \.self) { col in
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .overlay {
                                        Image(systemName: "plus")
                                            .font(.largeTitle)
                                            .foregroundStyle(.tertiary)
                                    }
                                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Dashboard")
    }
    
    // MARK: - Header
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
            
            Button {
                // Edit Dashboard
            } label: {
                Label("Edit", systemImage: "slider.horizontal.3")
                    .font(.headline)
            }
            .buttonStyle(.bordered)
            .tint(.primary)
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
}
