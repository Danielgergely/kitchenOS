//
//  Tag.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 2/16/26.
//
import SwiftUI
import SwiftData

enum TagColor: String, Codable, CaseIterable {
    case red, orange, yellow, green, blue, purple, pink, indigo
    
    var displayColor: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .indigo: return .indigo
        }
    }
}

@Model
final class Tag {
    var id: UUID = UUID()
    var name: String
    var color: TagColor
    var icon: String
    
    var recipes: [Recipe]?
    var ingredients: [Ingredient]?
    
    init(id: UUID = UUID(), name: String, icon: String, color: TagColor = .blue) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
    }
}
