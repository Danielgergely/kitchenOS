//
//  WeekPlanView.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 2/16/26.
//
import SwiftUI
import SwiftData

enum ViewMode: Int, CaseIterable {
    case day = 1
    case threeDay = 3
    case week = 7
    
    var title: String {
        switch self {
        case .day: return "1 Day"
        case .threeDay: return "3 Days"
        case .week: return "Week"
        }
    }
}

struct WeekPlanView: View {
    @Environment(\.modelContext) public var modelContext
    @Query private var days: [Day]
    
    @State private var baseDate = Date()
    @State private var selectedPage: Int = 0
    @State private var viewMode: ViewMode = .week
    
    // Centralized presetnation state
    @State private var recipeToNavigate: Recipe?
    @State private var mealForNotes: PlannedMeal?
    @State private var isShowingRecipePicker = false
    @State private var selectedMealTypeForPicker: MealType?
    @State private var selectedDateForPicker: Date?
    
    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                let columnSpacing: CGFloat = 4
                let totalSpacing = columnSpacing * CGFloat(viewMode.rawValue - 1)
                let availableSpace = geometry.size.width - totalSpacing - 16
                let calculatedWidth = availableSpace / CGFloat(viewMode.rawValue)
                let columnWidth = viewMode == .week ? max(calculatedWidth, 160) : calculatedWidth
                
                TabView(selection: $selectedPage) {
                    ForEach(-50...50, id: \.self) { pageOffset in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: columnSpacing) {
                                ForEach(dates(for: pageOffset), id: \.self) { date in
                                    DayColumn(
                                        date: date,
                                        plan: plan(for: date),
                                        onRecipeTapped: { recipeToNavigate = $0 },
                                        onNotesTapped: { mealForNotes = $0 },
                                        onPickerTapped: { type, date in
                                            selectedMealTypeForPicker = type
                                            selectedDateForPicker = date
                                            isShowingRecipePicker = true
                                        }
                                    )
                                    .frame(width: columnWidth)
                                }
                            }
                            .padding(.horizontal, 8)
                            .frame(minWidth: geometry.size.width)
                        }
                        .tag(pageOffset)
                        .sheet(item: $recipeToNavigate) { recipe in
                            RecipeDetailView(recipe: recipe)
                        }
                        .sheet(item: $mealForNotes) { meal in
                            MealNotesSheet(meal: meal)
                        }
                        .sheet(isPresented: $isShowingRecipePicker) {
                            RecipePickerSheet(
                                onSelectRecipe: { recipe in
                                    if let type = selectedMealTypeForPicker, let date = selectedDateForPicker {
                                        assignRecipeToPlan(recipe: recipe, type: type, date: date)
                                    }
                                },
                                onSelectEatingOut: {
                                    if let type = selectedMealTypeForPicker, let date = selectedDateForPicker {
                                        assignEatingOutToPlan(type: type, date: date)
                                    }
                                }
                            )
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never)) // Enables horizontal swiping!
                .padding(.top, 4)
                .background(Color(uiColor: .systemGroupedBackground))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(headerDate.formatted("MMMM yyyy"))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Picker("View", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .buttonStyle(.plain)
            }
            .sharedBackgroundVisibility(.hidden)
            
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 20) {
                    Button(action: { moveTime(by: -1) } ) {
                        Image(systemName: "chevron.left")
                    }
                    Button("Today") {
                        withAnimation {
                            baseDate = Date()
                            selectedPage = 0
                        }
                    }
                    Button(action: { moveTime(by: 1) } ) {
                        Image(systemName: "chevron.right")
                    }
                }
            }
        }
        .onChange(of: viewMode) { _, _ in
            baseDate = headerDate
            selectedPage = 0
        }
        
    }
    
    func plan(for date: Date) -> Day? {
        return days.first { Calendar.current.isDate($0.date, inSameDayAs: date)}
    }
    
    var headerDate: Date {
        if viewMode == .week {
            return Calendar.current.date(byAdding: .weekOfYear, value: selectedPage, to: baseDate) ?? baseDate
        } else {
            return Calendar.current.date(byAdding: .day, value: selectedPage * viewMode.rawValue, to: baseDate) ?? baseDate
        }
    }
    
    func dates(for page: Int) -> [Date] {
        if viewMode == .week {
            let weekDate = Calendar.current.date(byAdding: .weekOfYear, value: page, to: baseDate) ?? baseDate
            return weekDate.weekDays
        } else {
            let pageBaseDate = Calendar.current.date(byAdding: .day, value: page * viewMode.rawValue, to: baseDate) ?? baseDate
            return (0..<viewMode.rawValue).compactMap { dayOffset in
                Calendar.current.date(byAdding: .day, value: dayOffset, to: pageBaseDate)
            }
        }
    }
    
    func moveTime(by steps: Int) {
        withAnimation(.easeInOut) {
            selectedPage += steps
        }
    }
    
    func assignRecipeToPlan(recipe: Recipe, type: MealType, date: Date) {
        let currentPlan = plan(for: date)
        if let existingPlan = currentPlan {
            if let existingMeal = existingPlan.plannedMeals.first(where: { $0.type == type }) {
                existingMeal.recipe = recipe
                existingMeal.title = nil
                existingMeal.cookingType = .homeCooked
            } else {
                let newMeal = PlannedMeal(type: type, recipe: recipe, day: existingPlan)
                existingPlan.plannedMeals.append(newMeal)
            }
        } else {
            let newPlan = Day(date: date)
            let newMeal = PlannedMeal(type: type, recipe: recipe, day: newPlan)
            newPlan.plannedMeals.append(newMeal)
            modelContext.insert(newPlan)
        }
    }
    
    func assignEatingOutToPlan(type: MealType, date: Date) {
        let currentPlan = plan(for: date)
        if let existingPlan = currentPlan {
            if let existingMeal = existingPlan.plannedMeals.first(where: { $0.type == type }) {
                existingMeal.recipe = nil
                existingMeal.title = "Eating Out"
                existingMeal.cookingType = .eatingOut
            } else {
                let newMeal = PlannedMeal(type: type, recipe: nil, day: existingPlan)
                newMeal.title = "Eating Out"
                newMeal.cookingType = .eatingOut
                existingPlan.plannedMeals.append(newMeal)
            }
        } else {
            let newPlan = Day(date: date)
            let newMeal = PlannedMeal(type: type, recipe: nil, day: newPlan)
            newMeal.title = "Eating Out"
            newMeal.cookingType = .eatingOut
            newPlan.plannedMeals.append(newMeal)
            modelContext.insert(newPlan)
        }
    }
}

struct DayColumn: View {
    @Environment(\.modelContext) private var modelContext
    
    let date: Date
    let plan: Day?
    
    @State private var expandedSlots: Set<MealType> = []
    
    let onRecipeTapped: (Recipe) -> Void
    let onNotesTapped: (PlannedMeal) -> Void
    let onPickerTapped: (MealType, Date) -> Void
    
    var body: some View {
        VStack(spacing: 4) {
            VStack {
                Text(date.formatted("EEE"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(date.formatted("d"))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Calendar.current.isDateInToday(date) ? .blue : .primary)
            }
            .padding(.bottom, 8)
            
            slot(for: .breakfast, isCollapsible: true)
            slot(for: .lunch)
            slot(for: .dinner)
            slot(for: .snack, isCollapsible: true, expandUp: true)
        }
        .padding(4)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    func slot(for type: MealType, isCollapsible: Bool = false, expandUp: Bool = false) -> some View {
        let plannedMeal = plan?.meal(for: type)
        let hasMeal = plannedMeal != nil
        let isExpanded = expandedSlots.contains(type)
        
        if isCollapsible && !hasMeal && !isExpanded {
            Button {
                withAnimation(.spring()) { _ = expandedSlots.insert(type) }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text(type.rawValue.capitalized)
                }
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundStyle(.tertiary.opacity(0.5))
                )
            }
        } else {
            MealSlotView(
                title: type.rawValue,
                meal: plannedMeal,
                expandUp: expandUp,
                onTap: {
                    if let recipe = plannedMeal?.recipe {
                        onRecipeTapped(recipe)
                    } else {
                        onPickerTapped(type, date)
                    }
                },
                onSwitch: {
                    onPickerTapped(type, date)
                },
                onDelete: {
                    if let mealToDelete = plannedMeal {
                        withAnimation(.spring()) {
                            modelContext.delete(mealToDelete)
                            if isCollapsible { expandedSlots.remove(type) }
                        }
                    }
                },
                onNotes: {
                    if let mealToNote = plannedMeal {
                        onNotesTapped(mealToNote)
                    }
                },
                onCloseEmpty: isCollapsible ? {
                    withAnimation(.spring()) {
                        _ = expandedSlots.remove(type)
                    }
                } : nil
            )
        }
    }
}
