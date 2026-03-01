//
//  MealNotes.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 2/27/26.
//
import SwiftUI
import SwiftData

struct MealNotesSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var meal: PlannedMeal
    
    @State private var isEditing = false
    
    var body: some View {
        NavigationStack {
            VStack {
                if isEditing {
                    // EDIT MODE
                    TextEditor(text: $meal.notes)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(uiColor: .secondarySystemBackground))
                        )
                        .padding()
                } else {
                    // VIEW MODE
                    ScrollView {
                        Text(meal.notes.isEmpty ? "No notes added yet." : meal.notes)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(meal.notes.isEmpty ? .secondary : .primary)
                            .padding()
                    }
                }
            }
            .navigationTitle("\(meal.type.rawValue.capitalized) Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Done" : "Edit") {
                        withAnimation {
                            isEditing.toggle()
                        }
                    }
                }
            }
        }
        .onAppear {
            if meal.notes.isEmpty {
                isEditing = true
            }
        }
    }
}
