//
//  AddPlaceholderSquare.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 2/28/26.
//
import SwiftUI

struct AddPlaceholderSquare: View {
    let title: String
    let icon: String
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.largeTitle)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .foregroundStyle(.tertiary)
            )
        }
        .buttonStyle(.plain)
    }
}
