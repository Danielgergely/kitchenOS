//
//  RecipeStoreService.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/21/26.
//

import Foundation
import Supabase

class RecipeStoreService {
    static let shared = RecipeStoreService()
    
    private init() {}
    
    /// Fetches all recipe books that are marked as published in the database
    func fetchAvailableBooks() async throws -> [StoreRecipeBook] {
        // 1. Point to the table
        // 2. Select all columns
        // 3. Filter where is_published == true
        // 4. Decode directly into our Swift array
        let books: [StoreRecipeBook] = try await supabase
            .from("recipe_books")
            .select()
            .eq("is_published", value: true)
            .execute()
            .value
        
        return books
    }
}
