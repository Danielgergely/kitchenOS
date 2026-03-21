//
//  AdminPublisher.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/21/26.
//
import Foundation
import SwiftUI
import Supabase
import SwiftData

class AdminPublishService {
    static let shared = AdminPublishService()
    
    private let bucketName = "store_assets"
    
    /// Publishes a complete RecipeBook to the Supabase Storefront
    func publishBookToStore(book: RecipeBook, price: Double = 0.0) async throws {
        print("🚀 Starting Automated Publish for: \(book.title)")
        
        let safeTitle = book.title.replacingOccurrences(of: " ", with: "_")
        let bookId = UUID() // Generate a new ID for the store version
        
        // --- 1. UPLOAD COVER IMAGE ---
        var coverUrlString: String? = nil
        if let coverData = book.image {
            print("📸 Uploading Cover Image...")
            coverUrlString = try await uploadImage(data: coverData, path: "covers/\(bookId.uuidString).jpg")
        }
        
        // --- 2. GENERATE & UPLOAD PREVIEW RECIPES ---
        print("🔍 Generating Previews...")
        var previews: [RecipePreview] = []
        
        let safeRecipes = book.recipes ?? []
        let previewCandidates = Array(safeRecipes.prefix(5))
        
        for recipe in previewCandidates {
            var recipeImageUrl: String? = nil
            if let recipeData = recipe.image {
                let imagePath = "previews/\(bookId.uuidString)_\(UUID().uuidString).jpg"
                recipeImageUrl = try await uploadImage(data: recipeData, path: imagePath)
            }
            
            let preview = RecipePreview(
                title: recipe.title,
                timeMinutes: recipe.prepTime.totalMinutes,
                category: recipe.type.rawValue,
                imageUrl: recipeImageUrl
            )
            previews.append(preview)
        }
        
        // --- 3. GENERATE & UPLOAD FULL JSON DATA ---
        print("📦 Generating JSON Backup...")
        guard let localJsonUrl = DataExchangeService.generateExportFile(from: safeRecipes, books: [book], filename: "\(safeTitle).json") else {
            throw NSError(domain: "PublishError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate JSON locally"])
        }
        
        let jsonData = try Data(contentsOf: localJsonUrl)
        let jsonPath = "books/\(bookId.uuidString).json"
        
        print("☁️ Uploading JSON to Storage...")
        let _ = try await supabase.storage.from(bucketName).upload(
            jsonPath,
            data: jsonData,
            options: FileOptions(contentType: "application/json")
        )
        
        let jsonDownloadUrl = try supabase.storage.from(bucketName).getPublicURL(path: jsonPath).absoluteString
        
        // --- 4. CREATE DATABASE RECORD ---
        print("📝 Writing to Database...")
        let storeBook = StoreRecipeBook(
            id: bookId,
            title: book.title,
            description: book.desc ?? "A wonderful collection of recipes.",
            author: "Admin",
            price: price,
            storekitId: price > 0 ? "com.kitchenos.\(safeTitle.lowercased())" : nil,
            coverImageUrl: coverUrlString,
            jsonDownloadUrl: jsonDownloadUrl,
            isPublished: true,
            recipeCount: safeRecipes.count,
            previewRecipes: previews
        )
        
        // Insert into the PostgreSQL table
        try await supabase.from("recipe_books").insert(storeBook).execute()
        
        await MainActor.run {
            book.storefrontId = bookId
            try? book.modelContext?.save()
        }
        
        print("✅ PUBLISH COMPLETE! \(book.title) is now live.")
    }
    
    // --- Helper Function to Compress & Upload Images ---
    private func uploadImage(data: Data, path: String) async throws -> String {
        guard let image = UIImage(data: data),
              let compressedData = image.jpegData(compressionQuality: 0.3) else {
            return ""
        }
        
        let _ = try await supabase.storage.from(bucketName).upload(
            path,
            data: compressedData,
            options: FileOptions(contentType: "image/jpeg")
        )
        
        return try supabase.storage.from(bucketName).getPublicURL(path: path).absoluteString
    }
}
