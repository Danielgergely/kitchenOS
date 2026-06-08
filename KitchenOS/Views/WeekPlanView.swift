//
//  WeekPlanView.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 2/16/26.
//
import SwiftUI
import SwiftData
import CloudKit

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

enum PlanSource: String {
    case mine, shared
}

struct WeekPlanView: View {
    @Environment(\.modelContext) public var modelContext
    @Environment(SharedPlanService.self) private var sharedPlan
    @Query private var days: [Day]
    @Query private var allRecipes: [Recipe]

    let coordinator = CloudKitSharingCoordinator.shared

    @State private var baseDate = Date()
    @State private var selectedPage: Int = 0
    @State private var viewMode: ViewMode = .week

    // Persisted across launches so the chosen view (My Plan / Shared) sticks.
    @AppStorage("weekPlan.planSource") private var planSourceRaw: String = PlanSource.mine.rawValue
    private var planSource: PlanSource {
        get { PlanSource(rawValue: planSourceRaw) ?? .mine }
        nonmutating set { planSourceRaw = newValue.rawValue }
    }

    @State private var showSharingSheet = false

    // Centralized presentation state for My Plan
    @State private var recipeToNavigate: Recipe?
    @State private var mealForNotes: PlannedMeal?
    @State private var isShowingRecipePicker = false
    @State private var selectedMealTypeForPicker: MealType?
    @State private var selectedDateForPicker: Date?

    // Presentation state for Shared Plan recipe picker
    @State private var isShowingSharedRecipePicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Loading / error feedback for shared plan mode.
            // Only show the spinner on a true cold load (no cached meals) — when meals
            // are already on screen we refresh silently in the background.
            if planSource == .shared && isInSharedPlan {
                if sharedPlan.isLoading && sharedPlan.meals.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.8)
                        Text("Loading shared plan…").font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(.bar)
                } else if let err = sharedPlan.error {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text(err).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        Spacer()
                        Button("Retry") {
                            Task { await sharedPlan.fetchMeals(for: dates(for: selectedPage), isOwner: isSharedPlanOwner) }
                        }
                        .font(.caption.bold())
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                }
            }

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
                                    columnView(for: date)
                                        .frame(width: columnWidth)
                                }
                            }
                            .padding(.horizontal, 8)
                            .frame(minWidth: geometry.size.width)
                        }
                        .tag(pageOffset)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .padding(.top, 4)
                .background(Color(uiColor: .systemGroupedBackground))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(headerDate.formatted("MMMM yyyy"))
        .sheet(item: $recipeToNavigate) { recipe in
            RecipeDetailView(recipe: recipe)
        }
        .sheet(item: $mealForNotes) { meal in
            MealNotesSheet(meal: meal)
        }
        // My Plan recipe picker
        .sheet(isPresented: $isShowingRecipePicker) {
            RecipePickerSheet(
                onSelectRecipe: { recipe in
                    if let type = selectedMealTypeForPicker, let date = selectedDateForPicker {
                        assignRecipeToPlan(recipe: recipe, type: type, date: date)
                    }
                },
                onSelectCustomMeal: { title, cookingType in
                    if let type = selectedMealTypeForPicker, let date = selectedDateForPicker {
                        assignCustomMealToPlan(title: title, type: type, cookingType: cookingType, date: date)
                    }
                }
            )
        }
        // Shared Plan recipe picker — writes to CloudKit shared zone
        .sheet(isPresented: $isShowingSharedRecipePicker) {
            RecipePickerSheet(
                onSelectRecipe: { recipe in
                    if let type = selectedMealTypeForPicker, let date = selectedDateForPicker {
                        let snapshot = DataExchangeService.snapshotRecipe(recipe)
                        Task { await sharedPlan.addMeal(date: date, mealType: type, title: recipe.title, notes: "", recipeData: snapshot, isOwner: isSharedPlanOwner) }
                    }
                },
                onSelectCustomMeal: { title, cookingType in
                    if let type = selectedMealTypeForPicker, let date = selectedDateForPicker {
                        let displayTitle = title.isEmpty ? cookingType.rawValue : title
                        Task { await sharedPlan.addMeal(date: date, mealType: type, title: displayTitle, notes: "", recipeData: nil, isOwner: isSharedPlanOwner) }
                    }
                }
            )
        }
        // Sharing management sheet — dedicated view for both owners and participants
        .sheet(isPresented: $showSharingSheet) {
            SharingSheet(coordinator: coordinator)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                HStack(spacing: 8) {
                    Picker("View", selection: $viewMode) {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)

                    // Toggle for participants (accepted share) and owners (created a share).
                    // Owner's plan IS the shared plan, but the toggle lets them confirm what others see.
                    if sharedPlan.hasAcceptedShare || coordinator.currentShare != nil {
                        Picker("Plan", selection: planSourceBinding) {
                            Text("My Plan").tag(PlanSource.mine)
                            Text("Shared").tag(PlanSource.shared)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 170)
                    }
                }
                .buttonStyle(.plain)
            }
            .sharedBackgroundVisibility(.hidden)

            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 20) {
                    // Sharing icon is always visible — tapping opens SharingSheet.
                    Button {
                        showSharingSheet = true
                    } label: {
                        Image(systemName: (sharedPlan.hasAcceptedShare || coordinator.currentShare != nil) ? "person.2.fill" : "person.2")
                            .foregroundStyle(planSource == .shared ? .blue : .primary)
                    }
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
        .onChange(of: planSourceRaw) { _, _ in
            if planSource == .shared {
                Task { await sharedPlan.fetchMeals(for: dates(for: selectedPage), isOwner: isSharedPlanOwner) }
            }
        }
        .onChange(of: selectedPage) { _, _ in
            if planSource == .shared {
                Task { await sharedPlan.fetchMeals(for: dates(for: selectedPage), isOwner: isSharedPlanOwner) }
            }
        }
        .onChange(of: sharedPlan.hasAcceptedShare) { _, accepted in
            if !accepted && !isSharedPlanOwner { planSource = .mine }
        }
        .onAppear {
            Task {
                await coordinator.loadOrCreateShare(ifExists: true)
                // Restore: if a shared view was persisted but no share exists, fall back.
                if planSource == .shared && !isInSharedPlan {
                    planSource = .mine
                } else if planSource == .shared {
                    // Refresh the persisted shared view in the background.
                    await sharedPlan.fetchMeals(for: dates(for: selectedPage), isOwner: isSharedPlanOwner)
                }
            }
        }
    }

    // Bridges the persisted raw string to the Picker's PlanSource selection.
    private var planSourceBinding: Binding<PlanSource> {
        Binding(get: { planSource }, set: { planSource = $0 })
    }

    // True when this device created the share (owner of the shared plan zone).
    var isSharedPlanOwner: Bool {
        coordinator.currentShare != nil && !sharedPlan.hasAcceptedShare
    }

    // True when the current user participates in a shared plan (either side).
    var isInSharedPlan: Bool { sharedPlan.hasAcceptedShare || isSharedPlanOwner }

    @ViewBuilder
    func columnView(for date: Date) -> some View {
        if planSource == .shared && isInSharedPlan {
            SharedDayColumn(
                date: date,
                sharedMeals: sharedPlan.meals.filter { Calendar.current.isDate($0.date, inSameDayAs: date) },
                isOwner: isSharedPlanOwner,
                onOpenRecipe: { entry in openSharedRecipe(entry) },
                onPickerTapped: { type, pickerDate in
                    selectedMealTypeForPicker = type
                    selectedDateForPicker = pickerDate
                    isShowingSharedRecipePicker = true
                }
            )
        } else {
            DayColumn(
                date: date,
                plan: plan(for: date),
                getPlan: { queryDate in plan(for: queryDate) },
                onRecipeTapped: { recipeToNavigate = $0 },
                onNotesTapped: { mealForNotes = $0 },
                onPickerTapped: { type, pickerDate in
                    selectedMealTypeForPicker = type
                    selectedDateForPicker = pickerDate
                    isShowingRecipePicker = true
                }
            )
        }
    }

    func plan(for date: Date) -> Day? {
        return days.first { Calendar.current.isDate($0.date, inSameDayAs: date)}
    }

    /// Opens a recipe planned in the shared view. Prefers a local copy (so editing/cooking
    /// mode work); otherwise builds a transient, read-only recipe from the shared snapshot.
    func openSharedRecipe(_ entry: SharedMealEntry) {
        guard let data = entry.sharedRecipeData,
              let transfer = try? JSONDecoder().decode(TransferRecipe.self, from: data) else { return }

        if let local = allRecipes.first(where: { $0.id == transfer.id || $0.sourceRecipeId == transfer.id }) {
            recipeToNavigate = local
            return
        }
        recipeToNavigate = Self.transientRecipe(from: transfer)
    }

    /// Builds an in-memory Recipe (not inserted into any context) from a shared snapshot.
    static func transientRecipe(from transfer: TransferRecipe) -> Recipe {
        let ingredients = transfer.ingredients.map { tIng in
            Ingredient(
                id: UUID(),
                name: tIng.name,
                amount: tIng.amount,
                unit: Unit(rawValue: tIng.unitRawValue) ?? .piece,
                category: Category(rawValue: tIng.categoryRawValue) ?? .food,
                desc: tIng.desc,
                icon: tIng.icon,
                image: tIng.imageData,
                calories: tIng.calories,
                tags: []
            )
        }
        let recipe = Recipe(
            title: transfer.title,
            summary: transfer.summary,
            instructions: transfer.instructions,
            image: transfer.imageData,
            type: FoodType(rawValue: transfer.typeRawValue) ?? .mainDish,
            prepTime: PreparationTime(prepTime: transfer.prepTime, cookingTime: transfer.cookTime),
            ingredients: ingredients,
            tags: []
        )
        recipe.sourceRecipeId = transfer.id
        return recipe
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
            let shiftedDate = Calendar.current.date(byAdding: .weekOfYear, value: page, to: baseDate) ?? baseDate
            let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: shiftedDate)?.start ?? shiftedDate
            return (0..<7).compactMap { dayOffset in
                Calendar.current.date(byAdding: .day, value: dayOffset, to: startOfWeek)
            }
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
        let snapshot = DataExchangeService.snapshotRecipe(recipe)
        let currentPlan = plan(for: date)
        if let existingPlan = currentPlan {
            if let existingMeal = existingPlan.plannedMeals?.first(where: { $0.type == type }) {
                existingMeal.recipe = recipe
                existingMeal.sharedRecipeData = snapshot
                existingMeal.title = nil
                existingMeal.cookingType = .homeCooked
            } else {
                let newMeal = PlannedMeal(type: type, day: existingPlan, recipe: recipe)
                newMeal.sharedRecipeData = snapshot
                existingPlan.plannedMeals?.append(newMeal)
            }
        } else {
            let newPlan = Day(date: date)
            let newMeal = PlannedMeal(type: type, day: newPlan, recipe: recipe)
            newMeal.sharedRecipeData = snapshot
            newPlan.plannedMeals?.append(newMeal)
            modelContext.insert(newPlan)
        }
    }

    func assignCustomMealToPlan(title: String, type: MealType, cookingType: CookingType, date: Date) {
        let currentPlan = plan(for: date)
        if let existingPlan = currentPlan {
            if let existingMeal = existingPlan.plannedMeals?.first(where: { $0.type == type }) {
                existingMeal.recipe = nil
                existingMeal.title = title.isEmpty ? cookingType.rawValue : title
                existingMeal.cookingType = cookingType
            } else {
                let newMeal = PlannedMeal(type: type, day: existingPlan, recipe: nil)
                newMeal.title = title.isEmpty ? cookingType.rawValue : title
                newMeal.cookingType = cookingType
                existingPlan.plannedMeals?.append(newMeal)
            }
        } else {
            let newPlan = Day(date: date)
            let newMeal = PlannedMeal(type: type, day: newPlan, recipe: nil)
            newMeal.title = title.isEmpty ? cookingType.rawValue : title
            newMeal.cookingType = cookingType
            newPlan.plannedMeals?.append(newMeal)
            modelContext.insert(newPlan)
        }
    }
}

// MARK: - My Plan column (SwiftData-backed)

struct DayColumn: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allRecipes: [Recipe]

    let date: Date
    let plan: Day?

    let getPlan: (Date) -> Day?

    @State private var expandedSlots: Set<MealType> = []

    let onRecipeTapped: (Recipe) -> Void
    let onNotesTapped: (PlannedMeal) -> Void
    let onPickerTapped: (MealType, Date) -> Void

    // MARK: - Save to Library

    /// Copies the recipe snapshot from a shared plan meal into the user's own library.
    /// Duplicate detection: if sourceRecipeId already matches an existing recipe, skip save.
    private func saveToLibrary(meal: PlannedMeal) {
        guard let data = meal.sharedRecipeData,
              let transfer = try? JSONDecoder().decode(TransferRecipe.self, from: data)
        else { return }

        // Prevent duplicate copies
        let alreadyExists = allRecipes.contains {
            $0.sourceRecipeId == transfer.id || $0.id == transfer.id
        }
        guard !alreadyExists else { return }

        let ingredients = transfer.ingredients.map { tIng in
            Ingredient(
                id: UUID(),
                name: tIng.name,
                amount: tIng.amount,
                unit: Unit(rawValue: tIng.unitRawValue) ?? .piece,
                category: Category(rawValue: tIng.categoryRawValue) ?? .food,
                desc: tIng.desc,
                icon: tIng.icon,
                image: tIng.imageData,
                calories: tIng.calories,
                tags: []
            )
        }

        let newRecipe = Recipe(
            title: transfer.title,
            summary: transfer.summary,
            instructions: transfer.instructions,
            image: transfer.imageData,
            type: FoodType(rawValue: transfer.typeRawValue) ?? .mainDish,
            prepTime: PreparationTime(prepTime: transfer.prepTime, cookingTime: transfer.cookTime),
            ingredients: ingredients,
            tags: []
        )
        newRecipe.sourceRecipeId = transfer.id
        modelContext.insert(newRecipe)
    }

    /// Returns true when the user already has a copy of the recipe from this meal.
    private func isAlreadySaved(meal: PlannedMeal) -> Bool {
        guard let data = meal.sharedRecipeData,
              let transfer = try? JSONDecoder().decode(TransferRecipe.self, from: data)
        else { return false }

        return allRecipes.contains {
            $0.sourceRecipeId == transfer.id || $0.id == transfer.id
        }
    }

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

        let leftoverImage: Data? = {
            guard plannedMeal?.cookingType == .leftovers else { return nil }
            guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date),
                  let yesterdayPlan = getPlan(yesterday) else { return nil }
            return yesterdayPlan.meal(for: .dinner)?.recipe?.image
                ?? yesterdayPlan.meal(for: .lunch)?.recipe?.image
        }()

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
                } : nil,
                onSaveToLibrary: plannedMeal.flatMap { meal -> (() -> Void)? in
                    guard meal.sharedRecipeData != nil, !isAlreadySaved(meal: meal) else { return nil }
                    return { saveToLibrary(meal: meal) }
                },
                isAlreadySaved: plannedMeal.map { isAlreadySaved(meal: $0) } ?? false,
                leftoverImageData: leftoverImage
            )
        }
    }
}

// MARK: - Shared Plan column (CloudKit shared zone)

struct SharedDayColumn: View {
    @Environment(SharedPlanService.self) private var sharedPlan

    let date: Date
    let sharedMeals: [SharedMealEntry]
    let isOwner: Bool
    let onOpenRecipe: (SharedMealEntry) -> Void
    let onPickerTapped: (MealType, Date) -> Void

    @State private var expandedSlots: Set<MealType> = []

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

            sharedSlot(for: .breakfast, isCollapsible: true)
            sharedSlot(for: .lunch)
            sharedSlot(for: .dinner)
            sharedSlot(for: .snack, isCollapsible: true, expandUp: true)
        }
        .padding(4)
        .background(Color(uiColor: .systemBackground).opacity(0.95))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.blue.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    func sharedSlot(for type: MealType, isCollapsible: Bool = false, expandUp: Bool = false) -> some View {
        let meal = sharedMeals.first(where: { $0.mealType == type })
        let hasMeal = meal != nil
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
            SharedMealSlotView(
                title: type.rawValue,
                meal: meal,
                expandUp: expandUp,
                onTap: {
                    if let m = meal {
                        // Open the recipe if this slot has one; custom meals have no snapshot.
                        if m.sharedRecipeData != nil { onOpenRecipe(m) }
                    } else {
                        onPickerTapped(type, date)
                    }
                },
                onDelete: {
                    if let m = meal {
                        Task { await sharedPlan.deleteMeal(id: m.id, isOwner: isOwner) }
                        if isCollapsible {
                            withAnimation(.spring()) { expandedSlots.remove(type) }
                        }
                    }
                },
                onCloseEmpty: isCollapsible ? {
                    withAnimation(.spring()) { _ = expandedSlots.remove(type) }
                } : nil
            )
        }
    }
}

// MARK: - Shared meal slot card

struct SharedMealSlotView: View {
    let title: String
    let meal: SharedMealEntry?
    let expandUp: Bool

    var onTap: () -> Void
    var onDelete: () -> Void
    var onCloseEmpty: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)

            ZStack(alignment: .topTrailing) {
                ZStack(alignment: .bottomLeading) {
                    // Background
                    if let meal {
                        if let imageData = meal.imageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 80, maxHeight: .infinity)
                                .clipped()
                                .overlay(Color.black.opacity(0.3))
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.blue.opacity(0.12))
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(uiColor: .secondarySystemBackground))
                    }

                    // Text content
                    if let meal {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(meal.recipeTitle ?? meal.mealType.rawValue.capitalized)
                                .font(.caption)
                                .fontWeight(.bold)
                                .lineLimit(2)
                                .foregroundStyle(meal.imageData != nil ? .white : .primary)
                            if !meal.notes.isEmpty {
                                Text(meal.notes)
                                    .font(.system(size: 9))
                                    .foregroundStyle(meal.imageData != nil ? .white.opacity(0.8) : .secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(8)
                    } else {
                        Image(systemName: "plus")
                            .font(.headline)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                }
                .frame(minHeight: 80, maxHeight: .infinity)
                .contentShape(Rectangle())
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .onTapGesture { onTap() }

                // Trash button when meal exists
                if meal != nil {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.red)
                            .frame(width: 28, height: 28)
                    }
                    .padding(4)
                } else if let onCloseEmpty {
                    Button(action: onCloseEmpty) {
                        Image(systemName: expandUp ? "chevron.down" : "chevron.up")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(6)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding(6)
                }
            }
        }
    }
}
