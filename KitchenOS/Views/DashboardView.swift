//
//  DashboardView.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/3/26.
//
import SwiftUI
import SwiftData

enum DashboardSlot: Codable, Equatable {
    case empty
    case widget(type: DashboardWidget, size: WidgetSize)
    case spanned
    
    var columnSpan: Int {
        if case .widget(_, let size) = self, size == .medium {
            return 2
        }
        return 1
    }
}

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query private var allRecipes: [Recipe]
    @Query private var allMeals: [PlannedMeal]
    @Query(filter: #Predicate<ShoppingItem> { $0.isChecked == false })
    private var pendingShoppingItems: [ShoppingItem]
    
    var isSidebarOpen: Bool
    @State private var widgetLayout: [DashboardSlot] = Array(repeating: .empty, count: 9)
    @State private var sidebarWidth: CGFloat = 320.0
    
    @AppStorage("dashboardLayout") var layoutData: Data = Data()
    
    @State private var selectedSlotIndex: Int?
    @State private var showingWidgetPicker = false
    
    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            let spacing: CGFloat = 16
            
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                
                let masterLayout = isLandscape ? AnyLayout(HStackLayout(spacing: spacing)) : AnyLayout(VStackLayout(spacing: spacing))
                
                masterLayout {
                    TodayWidget(meals: allMeals, isLandscape: isLandscape)
                        .frame(
                            width: isLandscape ? (geo.size.width - spacing) * 0.4 : nil,
                            height: isLandscape ? nil : (geo.size.height - spacing) * 0.4
                        )
                    
                    Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
                        ForEach(0..<3, id: \.self) { row in
                            GridRow {
                                ForEach(0..<3, id: \.self) { col in
                                    let index = row * 3 + col
                                    let slot = widgetLayout[index]
                                    
                                    // Only render the view if it is NOT covered by a neighbor
                                    if slot != .spanned {
                                        widgetSlot(index: index, slot: slot)
                                            .gridCellColumns(slot.columnSpan)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Dashboard")
        .sheet(isPresented: $showingWidgetPicker) {
            WidgetSelectorSheet { selectedWidget, selectedSize in
                if let index = selectedSlotIndex {
                    placeWidget(selectedWidget, size: selectedSize, at: index)
                }
            }
        }
        .onAppear(perform: loadLayout)
    }
    
    // MARK: - Widget Slot Helper
    @ViewBuilder
    private func widgetSlot(index: Int, slot: DashboardSlot) -> some View {
        Group {
            switch slot {
            case .widget(let widgetType, let size):
                renderWidget(widgetType, size: size)
            case .empty, .spanned:
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .overlay {
                        Image(systemName: "plus")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                    }
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onTapGesture {
            selectedSlotIndex = index
            showingWidgetPicker = true
        }
    }

    @ViewBuilder
    private func renderWidget(_ type: DashboardWidget, size: WidgetSize) -> some View {
        switch type {
        case .mostCooked: MostCookedWidget(recipes: allRecipes, size: size)
        case .highestRated: HighestRatedWidget(recipes: allRecipes, size: size)
        case .habits: CookingHabitsWidget(meals: allMeals, size: size)
        case .shopping: ShoppingListWidget(items: pendingShoppingItems, size: size)
        case .totalRecipes: TotalRecipesWidget(recipeCount: allRecipes.count, size: size)
        }
    }
    
    private func placeWidget(_ widget: DashboardWidget, size: WidgetSize, at index: Int) {
        let col = index % 3 // 0, 1, or 2
        
        if size == .medium {
            // Only allow medium if placed in column 0 or 1
            if col < 2 {
                widgetLayout[index] = .widget(type: widget, size: size)
                widgetLayout[index + 1] = .spanned // Consume the next slot!
            } else {
                // Not enough space, fallback to small
                widgetLayout[index] = .widget(type: widget, size: .small)
            }
        } else {
            widgetLayout[index] = .widget(type: widget, size: size)
            
            // Clean up: If we previously had a medium widget here, un-span the neighbor
            if index < 8 && widgetLayout[index + 1] == .spanned {
                widgetLayout[index + 1] = .empty
            }
        }
        saveLayout()
    }
    
    // MARK: - Layout Persistence
    private func saveLayout() {
        if let encoded = try? JSONEncoder().encode(widgetLayout) {
            layoutData = encoded
        }
    }
    
    private func loadLayout() {
        if let decoded = try? JSONDecoder().decode([DashboardSlot].self, from: layoutData) {
            widgetLayout = decoded
        }
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
        }
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
