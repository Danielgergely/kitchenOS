//
//  RecommendationSheet.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/13/26.
//
import SwiftUI
import SwiftData

struct RecommendationSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @Query(filter: #Predicate<UserPreferences> { $0.id == "currentUser" }) private var prefQuery: [UserPreferences]
    @Query private var plannedMeals: [PlannedMeal]
    @Query private var allRecipes: [Recipe]
    
    var prefilledDate: Date? = nil
    var prefilledMealType: MealType? = nil
    var onAccept: ((Recipe) -> Void)? = nil
    
    @Query private var allPlannedMeals: [PlannedMeal]

    private var pastMeals: [PlannedMeal] {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .distantPast
        return allPlannedMeals.filter {
            $0.day.date < Date.now && $0.day.date >= thirtyDaysAgo
        }
    }
    
    private var upcomingMeals: [PlannedMeal] {
        return allPlannedMeals.filter {
            $0.day.date >= Date.now
        }
    }
    
    @State private var context: RecommendationContext
    
    @State private var isGenerating = false
    @State private var recommendedRecipe: Recipe?
    @State private var recommendationReason: String = ""
    @State private var errorMessage: String?
    @State private var showingPlanner = false

    init(prefilledDate: Date? = nil, prefilledMealType: MealType? = nil, onAccept: ((Recipe) -> Void)? = nil) {
        self.prefilledDate = prefilledDate
        self.prefilledMealType = prefilledMealType
        self.onAccept = onAccept
        
        _context = State(initialValue: RecommendationContext(mealType: prefilledMealType ?? .dinner))
    }
    
    @State private var recommendations: [(recipe: Recipe, reason: String)] = []
    
    var body: some View {
        NavigationStack {
            Form {
                if allRecipes.isEmpty {
                    ContentUnavailableView(
                        "Library Empty",
                        systemImage: "book.closed",
                        description: Text("Add some recipes to your library before asking for recommendations.")
                    )
                } else {
                    requestSection
                    
                    if isGenerating {
                        loadingSection
                    } else if !recommendations.isEmpty {
                        ForEach(recommendations.indices, id: \.self) { idx in
                            let rec = recommendations[idx]
                            resultSection(recipe: rec.recipe, reason: rec.reason, index: idx + 1)
                        }
                    } else if let error = errorMessage {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("AI Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Recommend") { generate() }
                        .disabled(isGenerating || allRecipes.isEmpty)
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var requestSection: some View {
        Section {
            Picker("Meal Type", selection: $context.mealType) {
                ForEach(MealType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            
            HStack {
                Text("Max Time")
                Spacer()
                if let override = context.timeOverride {
                    Text("\(override) min").foregroundStyle(.secondary)
                } else if let defaultTime = currentPrefs.maxPrepTimeMinutes {
                    Text("\(defaultTime) min (Default)").foregroundStyle(.secondary)
                } else {
                    Text("Any").foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    
                switch context.timeOverride {
                case nil:
                    context.timeOverride = 30
                case 30:
                    context.timeOverride = 60
                case 60:
                    context.timeOverride = 90
                default:
                    context.timeOverride = nil
                }
            }
            
            TextField("What are you craving? (e.g., Spicy, Comforting)", text: $context.vibe)
            TextField("Ingredients to use (e.g., Chicken, Rice)", text: $context.includedIngredients)
        } header: {
            Text("Current Request")
        } footer: {
            Text("Your preferences (Diet: \(currentPrefs.dietaryPreferences.rawValue)) are applied automatically.")
        }
    }
    
    private var loadingSection: some View {
        HStack {
            Spacer()
            VStack(spacing: 12) {
                ProgressView()
                Text("Scanning your library...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            Spacer()
        }
        .listRowBackground(Color.clear)
    }
    
    private func resultSection(recipe: Recipe) -> some View {
        Section("Chef's Suggestion") {
            VStack(alignment: .leading, spacing: 12) {
                Text(recommendationReason)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .italic()
                
                RecipeSquare(recipe: recipe)
                    .frame(height: 180)
            }
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            
            Button {
                if let onAccept {
                    onAccept(recipe)
                } else {
                    showingPlanner = true
                }
            } label: {
                Text(onAccept != nil ? "Accept Suggestion" : "Plan this Meal")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 16, leading: 0, bottom: 0, trailing: 0))
        }
        .sheet(isPresented: $showingPlanner) {
            MealPlannerSheet(recipe: recipe, initialDate: prefilledDate)
        }
    }
    
    private func resultSection(recipe: Recipe, reason: String, index: Int) -> some View {
        Section("Chef's Suggestion #\(index)") {
            VStack(alignment: .leading, spacing: 12) {
                Text(reason)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .italic()

                RecipeSquare(recipe: recipe)
                    .frame(height: 180)
            }
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            Button {
                if let onAccept {
                    onAccept(recipe)
                } else {
                    showingPlanner = true
                }
            } label: {
                Text(onAccept != nil ? "Accept Suggestion" : "Plan this Meal")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 16, leading: 0, bottom: 0, trailing: 0))
        }
        .sheet(isPresented: $showingPlanner) {
            MealPlannerSheet(recipe: recipe, initialDate: prefilledDate)
        }
    }
    
    // MARK: - Logic
    
    private var currentPrefs: UserPreferences {
        prefQuery.first ?? UserPreferences()
    }
    
    private func generate() {
        isGenerating = true
        recommendedRecipe = nil
        errorMessage = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        Task {
            do {
                let results = try await AIService.shared.recommendFromLibrary(
                    context: context,
                    preferences: currentPrefs,
                    upcomingMeals: upcomingMeals,
                    pastMeals: pastMeals,
                    availableRecipes: allRecipes
                )
                
                await MainActor.run {
                    var matched: [(Recipe, String)] = []
                    for result in results {
                        if let recipe = allRecipes.first(where: { $0.id == result.recipeId }) {
                            matched.append((recipe, result.reason))
                        }
                    }
                    
                    if matched.isEmpty {
                        self.errorMessage = "AI suggested recipes that couldn't be found."
                    } else {
                        self.recommendations = matched
                    }
                    self.isGenerating = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to get recommendations: \(error.localizedDescription)"
                    self.isGenerating = false
                }
            }
        }
    }
}

