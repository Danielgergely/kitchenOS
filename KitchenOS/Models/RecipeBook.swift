//
//  RecipeBook.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 2/28/26.
//
import Foundation
import SwiftData

@Model
class RecipeBook {
    var id: UUID
    var title: String
    var icon: String
    @Attribute(.externalStorage) var image: Data?
    
    @Relationship(deleteRule: .nullify, inverse: \Recipe.book)
    var recipes: [Recipe]? = []
    
    init(id: UUID = UUID(), title: String, icon: String = "folder", image: Data? = nil, recipes: [Recipe]? = nil) {
        self.id = id
        self.title = title
        self.icon = icon
        self.image = image
        self.recipes = recipes
    }
}
