//
//  DataExchangeService.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/1/26.
//
import SwiftUI
import SwiftData

class DataExchangeService {
    
    static func generateExportFile(from recipes: [Recipe], books: [RecipeBook]) -> URL? {
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
            let fileURL = tempDir.appendingPathComponent("KitchenOS_Export.json")
            try data.write(to: fileURL)
            
            return fileURL
            
        } catch {
            print("Failed to encode recipes: \(error.localizedDescription)")
            return nil
        }
    }
    
    static func importRecipes(from url: URL, context: ModelContext) {
        guard url.startAccessingSecurityScopedResource() else {
            print("Permission denied to access the file.")
            return
        }
        
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let data = try Data(contentsOf: url)
            
            let backup = try JSONDecoder().decode(TransferBackup.self, from: data)
            
            var restoredBooks: [UUID: RecipeBook] = [:]
            
            for tBook in backup.books {
                let newBook = RecipeBook(title: tBook.title, icon: tBook.icon, image: tBook.imageData)
                context.insert(newBook)
                restoredBooks[tBook.id] = newBook
            }
            
            // Translate the Transfer models back into real SwiftData models
            for transfer in backup.recipes {
                
                let ingredients = transfer.ingredients.map { tIng in
                    // Reconstruct the ingredient's tags
                    let ingTags = tIng.tags.map { tTag in
                        Tag(
                            id: UUID(),
                            name: tTag.name,
                            icon: tTag.icon,
                            color: TagColor(rawValue: tTag.colorRawValue) ?? .blue
                        )
                    }
                    
                    return Ingredient(
                        id: UUID(),
                        name: tIng.name,
                        amount: tIng.amount,
                        unit: Unit(rawValue: tIng.unitRawValue) ?? .piece,
                        category: Category(rawValue: tIng.categoryRawValue) ?? .food,
                        desc: tIng.desc,
                        icon: tIng.icon,
                        image: tIng.imageData,
                        calories: tIng.calories,
                        tags: ingTags
                    )
                }
                
                let tags = transfer.tags.map { tTag in
                    Tag(
                        id: UUID(),
                        name: tTag.name,
                        icon: tTag.icon,
                        color: TagColor(rawValue: tTag.colorRawValue) ?? .blue
                    )
                }
                
                let newRecipe = Recipe(
                    title: transfer.title,
                    summary: transfer.summary,
                    instructions: transfer.instructions,
                    image: transfer.imageData,
                    type: FoodType(rawValue: transfer.typeRawValue) ?? .mainDish,
                    prepTime: PreparationTime(prepTime: transfer.prepTime, cookingTime: transfer.cookTime),
                    ingredients: ingredients,
                    tags: tags
                )
                
                if let oldBookId = transfer.bookId, let matchingBook = restoredBooks[oldBookId] {
                    newRecipe.book = matchingBook
                }
                
                context.insert(newRecipe)
            }
            
            print("Successfully imported \(backup.books.count) books and \(backup.recipes.count) recipes!")
        } catch {
            print("Failed to import recipes: \(error.localizedDescription)")
        }
    }
}
