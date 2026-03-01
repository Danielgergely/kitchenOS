//
//  EditIngredientsRow.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 2/19/26.
//
import SwiftUI

struct EditIngredientsRow: View {
    @Bindable var ingredient: Ingredient
    
    var onDelete: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            TextField("Item (e.g. Flour)", text: $ingredient.name)
            
            Spacer()
            
            TextField("0", value: $ingredient.amount, format: .number)
                .keyboardType(.numberPad)
            
            Picker("Unit", selection: $ingredient.unit) {
                ForEach(Unit.allCases, id: \.self) { unit in
                    Text(unit.rawValue).tag(unit)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.red.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
    }
}
