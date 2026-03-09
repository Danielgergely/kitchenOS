//
//  PreferencesForm.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/9/26.
//
import SwiftUI

struct PreferencesForm: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var profile: UserPreferences
    
    // Helpers to quickly edit arrays via comma-separated TextFields
    private var allergiesBinding: Binding<String> { arrayBinding(for: \.allergies) }
    private var dislikesBinding: Binding<String> { arrayBinding(for: \.dislikedIngredients) }
    
    var body: some View {
        Form(content: {
            Section(header: Text("Diet & Health"), footer: Text("These hard constraints are always respected by the AI.")) {
                Picker("Dietary Preference", selection: $profile.dietaryPreferences) {
                    ForEach(DietaryPreference.allCases, id: \.self) { diet in
                        Text(diet.rawValue).tag(diet)
                    }
                }
                
                TextField("Allergies (e.g., Peanuts, Gluten)", text: allergiesBinding)
                TextField("Dislikes (e.g., Cilantro, Mushrooms)", text: dislikesBinding)
                
                HStack {
                    Text("Target Calories")
                    Spacer()
                    TextField("Optional", value: $profile.targetDailyCalories, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section(header: Text("Lifestyle & Schedule")) {
                Toggle("Plan Leftovers for Lunch", isOn: $profile.planLeftovers)
                
                HStack {
                    Text("Max Prep Time (minutes)")
                    Spacer()
                    TextField("e.g., 30", value: $profile.maxPrepTimeMinutes, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section(header: Text("Kitchen & Capabilities")) {
                Picker("Cooking Skill", selection: $profile.cookingSkillLevel) {
                    ForEach(SkillLevel.allCases, id: \.self) { skill in
                        Text(skill.rawValue).tag(skill)
                    }
                }
            }
        })
        .navigationTitle("Taste Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
    
    // Helper to map [String] to a comma-separated String for TextField
    private func arrayBinding(for keyPath: ReferenceWritableKeyPath<UserPreferences, [String]>) -> Binding<String> {
        Binding(
            get: { profile[keyPath: keyPath].joined(separator: ", ") },
            set: { newValue in
                profile[keyPath: keyPath] = newValue.components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
        )
    }
}

