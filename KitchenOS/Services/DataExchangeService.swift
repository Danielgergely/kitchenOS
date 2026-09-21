//
//  DataExchangeService.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/1/26.
//
//  Export / import / share-snapshot plumbing. The actual model ↔ DTO conversion
//  lives in RecipeTransfer.swift so every path uses the same mapping.
//
import SwiftUI
import SwiftData

enum DataExchangeService {

    // MARK: - Export

    static func generateExportFile(from recipes: [Recipe], books: [RecipeBook], filename: String = "MealOS_Export.json") -> URL? {
        let backup = TransferBackup(
            books: books.map { TransferRecipeBook($0) },
            recipes: recipes.map { TransferRecipe($0) }
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(backup)

            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Failed to encode recipes: \(error.localizedDescription)")
            return nil
        }
    }

    /// Encodes a single recipe into JSON for the `sharedRecipeData` snapshot carried
    /// by planned meals. The other household member uses it to display recipe details
    /// even when they don't have the recipe in their own library.
    static func snapshotRecipe(_ recipe: Recipe) -> Data? {
        try? JSONEncoder().encode(TransferRecipe(recipe))
    }

    // MARK: - Import

    /// Reads the file without saving anything yet, so the caller can ask about collisions.
    static func peekImportFile(from url: URL) throws -> TransferBackup {
        guard url.startAccessingSecurityScopedResource() else {
            throw NSError(domain: "DataExchange", code: 1, userInfo: [NSLocalizedDescriptionKey: "Permission denied."])
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(TransferBackup.self, from: data)
    }

    static func executeImport(backup: TransferBackup, context: ModelContext, overwrite: Bool) throws {
        let existingBooks = try context.fetch(FetchDescriptor<RecipeBook>())
        let existingBooksMap = Dictionary(uniqueKeysWithValues: existingBooks.map { ($0.id, $0) })

        let resolveTag = makeTagResolver(context: context)
        var restoredBooks: [UUID: RecipeBook] = [:]

        // Books & collisions
        for tBook in backup.books {
            if let existingBook = existingBooksMap[tBook.id] {
                guard overwrite else { continue }
                existingBook.title = tBook.title
                existingBook.icon = tBook.icon
                existingBook.image = tBook.imageData

                // Delete the book's old recipes so overwriting doesn't duplicate them.
                for oldRecipe in existingBook.recipes ?? [] {
                    context.delete(oldRecipe)
                }
                restoredBooks[tBook.id] = existingBook
            } else {
                let newBook = RecipeBook(id: tBook.id, title: tBook.title, icon: tBook.icon, image: tBook.imageData)
                context.insert(newBook)
                restoredBooks[tBook.id] = newBook
            }
        }

        // Existing recipes for de-duplication (by origin id or sourceRecipeId).
        let existingRecipes = (try? context.fetch(FetchDescriptor<Recipe>())) ?? []
        var seenIds = Set(existingRecipes.map { $0.id })
        seenIds.formUnion(existingRecipes.compactMap { $0.sourceRecipeId })

        for transfer in backup.recipes {
            if seenIds.contains(transfer.id) && !overwrite { continue }
            seenIds.insert(transfer.id)

            let newRecipe = transfer.makeRecipe(resolveTag: resolveTag)
            // Link to its book if that book came along in this backup; otherwise import
            // it as a standalone library recipe (covers single-recipe shares).
            if let oldBookId = transfer.bookId, let matchingBook = restoredBooks[oldBookId] {
                newRecipe.book = matchingBook
            }
            context.insert(newRecipe)
        }

        try context.save()
    }

    /// Reuses an existing tag with the same name, or inserts a new one — so importing
    /// never creates duplicate tags.
    private static func makeTagResolver(context: ModelContext) -> TagResolver {
        let existingTags = (try? context.fetch(FetchDescriptor<Tag>())) ?? []
        var cache: [String: Tag] = existingTags.reduce(into: [:]) { $0[$1.name] = $1 }

        return { tTag in
            if let existing = cache[tTag.name] { return existing }
            let newTag = Tag(id: UUID(), name: tTag.name, icon: tTag.icon, color: TagColor(rawValue: tTag.colorRawValue) ?? .blue)
            context.insert(newTag)
            cache[tTag.name] = newTag
            return newTag
        }
    }

    // MARK: - Sharing convenience

    /// Builds a shareable JSON file for a single recipe (imported as a standalone recipe).
    static func exportRecipe(_ recipe: Recipe) -> URL? {
        generateExportFile(from: [recipe], books: [], filename: "\(safeFilename(recipe.title)).json")
    }

    /// Builds a shareable JSON file for a whole cookbook and its recipes.
    static func exportBook(_ book: RecipeBook) -> URL? {
        generateExportFile(from: book.recipes ?? [], books: [book], filename: "\(safeFilename(book.title)).json")
    }

    private static func safeFilename(_ name: String) -> String {
        let cleaned = name
            .components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>"))
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "MealOS_Recipe" : cleaned
    }
}
