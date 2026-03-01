//
//  TagPil.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/1/26.
//
import SwiftUI
import SwiftData

struct TagPill: View {
    let tag: Tag
    var isSelected: Bool = true
    
    var body: some View {
        HStack(spacing: 4) {
            Image(tag.icon)
            Text(tag.name)
        }
        .font(.caption.bold())
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundStyle(isSelected ? .white : tag.color.displayColor)
        .background(isSelected ? tag.color.displayColor : tag.color.displayColor.opacity(0.15))
        .clipShape(Capsule())
    }
}
