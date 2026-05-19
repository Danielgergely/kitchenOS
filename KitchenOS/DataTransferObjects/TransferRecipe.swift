//
//  TransferRecipe.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/1/26.
//
import SwiftUI
import SwiftData

struct TransferRecipe: Codable {
    let id: UUID
    let title: String
    let summary: String
    let instructions: String
    let imageData: Data?
    let typeRawValue: String
    let prepTime: Int
    let cookTime: Int
    let ingredients: [TransferIngredient]
    let tags: [TransferTag]
    let bookId: UUID?

    init(id: UUID = UUID(), title: String, summary: String, instructions: String, imageData: Data?, typeRawValue: String, prepTime: Int, cookTime: Int, ingredients: [TransferIngredient], tags: [TransferTag], bookId: UUID?) {
        self.id = id
        self.title = title
        self.summary = summary
        self.instructions = instructions
        self.imageData = imageData
        self.typeRawValue = typeRawValue
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.ingredients = ingredients
        self.tags = tags
        self.bookId = bookId
    }

    enum CodingKeys: String, CodingKey {
        case id, title, summary, instructions, imageData, typeRawValue, prepTime, cookTime, ingredients, tags, bookId
    }

    // `id` was added after some store JSON was published — default to a new UUID when absent.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        title = try c.decode(String.self, forKey: .title)
        summary = try c.decode(String.self, forKey: .summary)
        instructions = try c.decode(String.self, forKey: .instructions)
        imageData = try? c.decode(Data.self, forKey: .imageData)
        typeRawValue = try c.decode(String.self, forKey: .typeRawValue)
        prepTime = try c.decode(Int.self, forKey: .prepTime)
        cookTime = try c.decode(Int.self, forKey: .cookTime)
        ingredients = try c.decode([TransferIngredient].self, forKey: .ingredients)
        tags = try c.decode([TransferTag].self, forKey: .tags)
        bookId = try? c.decode(UUID.self, forKey: .bookId)
    }
}
