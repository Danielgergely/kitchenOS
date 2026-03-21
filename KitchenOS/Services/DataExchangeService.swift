//
//  DataExchangeService.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/1/26.
//
import SwiftUI
import SwiftData

class DataExchangeService {
    
    static func generateExportFile(from recipes: [Recipe], books: [RecipeBook], filename: String = "KitchenOS_Export.json") -> URL? {
        // Books
        let transferBooks = books.map { book in
            TransferRecipeBook(
                id: book.id,
                title: book.title,
                icon: book.icon,
                imageData: book.image
            )
        }
        
        // Recipes
        let transferRecipes = recipes.map { recipe in
            let transferIngredients = recipe.ingredients.map { ing in
                let ingTags = ing.tags.map { tag in
                        TransferTag(name: tag.name, icon: tag.icon, colorRawValue: tag.color.rawValue)
                    }
                    
                    return TransferIngredient(
                        name: ing.name,
                        amount: ing.amount,
                        unitRawValue: ing.unit.rawValue,
                        categoryRawValue: ing.category.rawValue,
                        desc: ing.desc,
                        icon: ing.icon,
                        imageData: ing.image,
                        calories: ing.calories,
                        tags: ingTags
                    )
            }
            
            let transferTags = recipe.tags.map { tag in
                TransferTag(name: tag.name, icon: tag.icon, colorRawValue: tag.color.rawValue)
            }
            
            return TransferRecipe(
                title: recipe.title,
                summary: recipe.summary,
                instructions: recipe.instructions,
                imageData: recipe.image,
                typeRawValue: recipe.type.rawValue,
                prepTime: recipe.prepTime.prepTime,
                cookTime: recipe.prepTime.cookingTime,
                ingredients: transferIngredients,
                tags: transferTags,
                bookId: recipe.book?.id
            )
        }
        
        let backup = TransferBackup(books: transferBooks, recipes: transferRecipes)
        
        // 2. Encode to JSON
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(backup)
            
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent(filename)
            try data.write(to: fileURL)
            
            return fileURL
            
        } catch {
            print("Failed to encode recipes: \(error.localizedDescription)")
            return nil
        }
    }
    
    // 1. Read the file without saving anything yet
    static func peekImportFile(from url: URL) throws -> TransferBackup {
        guard url.startAccessingSecurityScopedResource() else {
            throw NSError(domain: "DataExchange", code: 1, userInfo: [NSLocalizedDescriptionKey: "Permission denied."])
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(TransferBackup.self, from: data)
    }
    
    // 2. Import execution (with overwrite handling)
    static func executeImport(backup: TransferBackup, context: ModelContext, overwrite: Bool) throws {
        // Fetch existing books to check for collisions
        let existingBooks = try context.fetch(FetchDescriptor<RecipeBook>())
        let existingBooksMap = Dictionary(uniqueKeysWithValues: existingBooks.map { ($0.id, $0) })
        
        let tagDescriptor = FetchDescriptor<Tag>()
        let existingTags = (try? context.fetch(tagDescriptor)) ?? []
        var tagCache: [String: Tag] = existingTags.reduce(into: [:]) { $0[$1.name] = $1 }
        
        let resolveTag: (TransferTag) -> Tag = { tTag in
            if let existing = tagCache[tTag.name] { return existing }
            let newTag = Tag(id: UUID(), name: tTag.name, icon: tTag.icon, color: TagColor(rawValue: tTag.colorRawValue) ?? .blue)
            context.insert(newTag)
            tagCache[tTag.name] = newTag
            return newTag
        }
        
        var restoredBooks: [UUID: RecipeBook] = [:]
        
        // Handle Books & Collisions
        for tBook in backup.books {
            if let existingBook = existingBooksMap[tBook.id] {
                if overwrite {
                    // Update properties
                    existingBook.title = tBook.title
                    existingBook.icon = tBook.icon
                    existingBook.image = tBook.imageData
                    
                    // DELETE old recipes inside this book to prevent duplicates!
                    for oldRecipe in existingBook.recipes ?? [] {
                        context.delete(oldRecipe)
                    }
                    restoredBooks[tBook.id] = existingBook
                } else {
                    continue
                }
            } else {
                // Insert new book
                let newBook = RecipeBook(id: tBook.id, title: tBook.title, icon: tBook.icon, image: tBook.imageData)
                context.insert(newBook)
                restoredBooks[tBook.id] = newBook
            }
        }
        
        // Translate Recipes
        for transfer in backup.recipes {
            // Only import recipes if their parent book was successfully imported/overwritten
            guard let oldBookId = transfer.bookId, let matchingBook = restoredBooks[oldBookId] else {
                continue
            }
            
            let ingredients = transfer.ingredients.map { tIng in
                let ingTags = tIng.tags.map { resolveTag($0) }
                return Ingredient(id: UUID(), name: tIng.name, amount: tIng.amount, unit: Unit(rawValue: tIng.unitRawValue) ?? .piece, category: Category(rawValue: tIng.categoryRawValue) ?? .food, desc: tIng.desc, icon: tIng.icon, image: tIng.imageData, calories: tIng.calories, tags: ingTags)
            }
            let tags = transfer.tags.map { resolveTag($0) }
            
            let newRecipe = Recipe(title: transfer.title, summary: transfer.summary, instructions: transfer.instructions, image: transfer.imageData, type: FoodType(rawValue: transfer.typeRawValue) ?? .mainDish, prepTime: PreparationTime(prepTime: transfer.prepTime, cookingTime: transfer.cookTime), ingredients: ingredients, tags: tags)
            
            newRecipe.book = matchingBook
            context.insert(newRecipe)
        }
        
        try context.save()
    }
}

