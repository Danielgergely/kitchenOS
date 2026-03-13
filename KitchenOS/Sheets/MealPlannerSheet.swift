//
//  MealPlannerSheet.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/7/26.
//

import SwiftUI
import SwiftData

struct MealPlannerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var allDays: [Day]
    
    let recipe: Recipe
    
    @State private var selectedDate: Date
    @State private var selectedMealType: MealType = .dinner
    
    init(recipe: Recipe, initialDate: Date? = nil) {
        self.recipe = recipe
        _selectedDate = State(initialValue: initialDate ?? Date())
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    MiniWeekPlannerView(selectedDate: $selectedDate, allDays: allDays)
                        .padding(.vertical, 8)
                } header: {
                    Text("Select Date")
                }
                
                Section {
                    Picker("Meal Slot", selection: $selectedMealType) {
                        ForEach(MealType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Select Meal")
                }
                
                // Show what is currently planned for the selected slot to prevent blind overwrites
                Section("Current Plan") {
                    if let existingMeal = mealForSelectedSlot {
                        HStack {
                            Image(systemName: existingMeal.cookingType == .eatingOut ? "takeoutbag.and.cup.and.straw" : "fork.knife")
                                .foregroundStyle(.secondary)
                            Text(existingMeal.displayTitle)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("Will be replaced")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    } else {
                        Text("Slot is available")
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Plan Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add to Plan") {
                        savePlan()
                    }
                }
            }
        }
    }
    
    // Helper to find what is currently planned for the selected date and meal type
    private var mealForSelectedSlot: PlannedMeal? {
        let day = allDays.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
        return day?.meal(for: selectedMealType)
    }
    
    private func savePlan() {
        var targetDay = allDays.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
        
        if targetDay == nil {
            let newDay = Day(date: Calendar.current.startOfDay(for: selectedDate))
            modelContext.insert(newDay)
            targetDay = newDay
        }
        
        guard let day = targetDay else { return }
        
        if let existingMeal = day.plannedMeals.first(where: { $0.type == selectedMealType }) {
            existingMeal.recipe = recipe
            existingMeal.title = nil
            existingMeal.cookingType = .homeCooked
        } else {
            let newMeal = PlannedMeal(type: selectedMealType, day: day, recipe: recipe)
            day.plannedMeals.append(newMeal)
        }
        
        dismiss()
    }
}

// MARK: - Mini Week View Component
struct MiniWeekPlannerView: View {
    @Binding var selectedDate: Date
    let allDays: [Day]
    
    @State private var weekOffset: Int = 0
    
    // Calculates the dates for the currently displayed week
    var weekDates: [Date] {
        let baseDate = Calendar.current.date(byAdding: .weekOfYear, value: weekOffset, to: Date()) ?? Date()
        return baseDate.weekDays
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header for Navigation
            HStack {
                Button {
                    withAnimation { weekOffset -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                
                Spacer()
                
                if let firstDate = weekDates.first {
                    Text(firstDate.formatted("MMMM yyyy"))
                        .font(.headline)
                }
                
                Spacer()
                
                Button {
                    withAnimation { weekOffset += 1 }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
            }
            .padding(.horizontal, 8)
            
            // Days Row
            HStack(spacing: 0) {
                ForEach(weekDates, id: \.self) { date in
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                    let dayPlan = allDays.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
                    
                    VStack(spacing: 6) {
                        Text(date.formatted("EEE").prefix(1))
                            .font(.caption2.bold())
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                        
                        Text(date.formatted("d"))
                            .font(.subheadline)
                            .fontWeight(isSelected ? .bold : .regular)
                            .foregroundStyle(isSelected ? Color(uiColor: .systemBackground) : .primary)
                            .frame(width: 32, height: 32)
                            .background(isSelected ? Color.accentColor : Color.clear)
                            .clipShape(Circle())
                        
                        // Indicators for Breakfast, Lunch, Dinner
                        HStack(spacing: 3) {
                            Circle()
                                .fill(dayPlan?.meal(for: .breakfast) != nil ? Color.orange : Color.clear)
                                .frame(width: 4, height: 4)
                            Circle()
                                .fill(dayPlan?.meal(for: .lunch) != nil ? Color.green : Color.clear)
                                .frame(width: 4, height: 4)
                            Circle()
                                .fill(dayPlan?.meal(for: .dinner) != nil ? Color.blue : Color.clear)
                                .frame(width: 4, height: 4)
                            Circle()
                                .fill(dayPlan?.meal(for: .snack) != nil ? Color.purple : Color.clear)
                                .frame(width: 4, height: 4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation {
                            selectedDate = date
                        }
                    }
                }
            }
            // Legend Row
            HStack(spacing: 16) {
                LegendIndicator(color: .orange, label: "Breakfast")
                LegendIndicator(color: .green, label: "Lunch")
                LegendIndicator(color: .blue, label: "Dinner")
                LegendIndicator(color: .purple, label: "Snack")
            }
            .padding(.top, 4)
        }
    }
}

struct LegendIndicator: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
