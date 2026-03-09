//
//  UserPreferencesSheet.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/9/26.
//
import SwiftUI
import SwiftData

struct UserPreferencesSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var preferencesQuery: [UserPreferences]
    
    var profile: UserPreferences? {
        preferencesQuery.first
    }
    
    var body: some View {
        NavigationStack {
            if let profile {
                PreferencesForm(profile: profile)
            } else {
                ContentUnavailableView("Loading Profile...", systemImage: "person.crop.circle.badge.questionmark")
                    .onAppear {
                        // Initialize the singleton if it doesn't exist
                        let newProfile = UserPreferences()
                        modelContext.insert(newProfile)
                        try? modelContext.save()
                    }
            }
        }
    }
}
