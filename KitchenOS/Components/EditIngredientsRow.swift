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
        GridRow {
            // Name Field
            TextField("Item (e.g. Flour)", text: $ingredient.name)
                .textFieldStyle(.plain)
                .padding(8)
                .background(Color(uiColor: .secondarySystemBackground).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Amount Field
            TextField("0", value: $ingredient.amount, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .frame(width: 60)
                .padding(8)
                .background(Color(uiColor: .secondarySystemBackground).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Unit Picker
            Picker("Unit", selection: $ingredient.unit) {
                ForEach(Unit.allCases, id: \.self) { unit in
                    Text(unit.rawValue).tag(unit)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 100)
            .padding(.horizontal, 4)
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .fixedSize(horizontal: true, vertical: false)
            
            // Remove button
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red.opacity(0.8))
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .gridColumnAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }
}
