import SwiftUI
import GoogleGenerativeAI

class AIService {
    // A shared instance so we can easily call it from anywhere
    static let shared = AIService()
    let config = GenerationConfig(responseMIMEType: "application/json")
    let apiKey = Secrets.googleApiKey
    let unitList = Unit.allCases.map { $0.rawValue }.joined(separator: ", ")
    let foodTypeList = FoodType.allCases.map { $0.rawValue }.joined(
        separator: ", "
    )
    
    // The list of models to rotate through!
    private let fallbackModels = [
        "gemini-2.5-flash",
        "gemini-3-flash-preview",
        "gemini-2.5-flash-lite",
        "gemini-2.5-pro"
    ]
    
    func getRecipeExtractionAIPrompt(extractFromText: String, tagList: String) -> String {
        return """
        You are a recipe extraction assistant.
        Extract the recipe from \(extractFromText). 
        Return a JSON object with the following keys:
        - title (String)
        - summary (String, a short 1-2 sentence description)
        - instructions (String, formatted step-by-step with line breaks)
        - prepTime (Int, minutes only)
        - cookTime (Int, minutes only)
        - type (String, choose exactly one from this list: \(foodTypeList))
        - tags (Array of Strings, select relevant tags ONLY from this list: \(tagList))
        - ingredients (Array of objects with 'name' (String), 'amount' (Double), 'unit' (String, choose exactly one from this list: \(unitList)))
        - imageUrl (String, the absolute URL of the main recipe image found in the HTML. Look for og:image meta tags or main article images. Return null if none found.)
        """
    }
    
    func callLLM(prompt: String, content: any ThrowingPartsRepresentable) async throws -> ExtractedRecipe {
        var lastError: Error?
        
        // Loop through our models one by one
        for modelName in fallbackModels {
            do {
                print("🤖 Attempting AI extraction with model: \(modelName)")
                let model = GenerativeModel(
                    name: modelName,
                    apiKey: apiKey,
                    generationConfig: config
                )
                let response = try await model.generateContent(prompt, content)
                
                guard let text = response.text, let data = text.data(using: .utf8) else {
                    print(
                        "⚠️ Could not read response from \(modelName). Trying next model..."
                    )
                    continue
                }
                
                print("🧠 Success with \(modelName)!")
                
                let extracted = try JSONDecoder().decode(
                    ExtractedRecipe.self,
                    from: data
                )
                return extracted
                
            } catch {
                print(
                    "❌ Model \(modelName) failed (likely rate limit): \(error.localizedDescription)"
                )
                lastError = error
            }
        }
        
        throw lastError ?? NSError(
            domain: "AIService",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "All fallback models failed."]
        )

    }
    
    // Notice this function is `async throws` and RETURNS the ExtractedRecipe
    func extractRecipeFromImage(from image: UIImage, availableTags: [String] = []) async throws -> ExtractedRecipe {
        let tagList = availableTags.isEmpty ? "None available" : availableTags.joined(
            separator: ", "
        )
        
        let prompt = getRecipeExtractionAIPrompt(
            extractFromText: "this image",
            tagList: tagList
        )
        
        return try await callLLM(prompt: prompt, content: image)
    }
    
    func extractRecipeFromURL(from url: URL, availableTags: [String] = []) async throws -> ExtractedRecipe {
        let tagList = availableTags.isEmpty ? "None available" : availableTags.joined(
            separator: ", "
        )
        // Fetch raw HTML
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(
                domain: "AI Service",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to load website. It might be blocked or offline."]
            )
        }
        
        guard let htmlContent = String(data: data, encoding: .utf8) else {
            throw NSError(
                domain: "AI Service",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Failed to read website content."]
            )
        }
        
        let prompt = getRecipeExtractionAIPrompt(
            extractFromText: "the provided website HTML",
            tagList: tagList
        )
        
        return try await callLLM(prompt: prompt, content: htmlContent)
    }
    
    func recommendFromLibrary(context: RecommendationContext, preferences: UserPreferences, upcomingMeals: [PlannedMeal], pastMeals: [PlannedMeal], availableRecipes: [Recipe]) async throws -> [LibraryRecommendationResult] {
        
        guard !availableRecipes.isEmpty else {
            throw NSError(
                domain: "AIService",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "No recipes in library."]
            )
        }
            
        let config = GenerationConfig(responseMIMEType: "application/json")
        let model = GenerativeModel(
            name: "gemini-3-flash-preview",
            apiKey: Secrets.googleApiKey,
            generationConfig: config
        )
            
        // 1. Format Constraints
        let upcomingTitles = upcomingMeals.compactMap { $0.displayTitle }.joined(
            separator: ", "
        )
        let pastTitles = pastMeals.compactMap { $0.displayTitle }.joined(separator: ", ")
        let allergiesStr = preferences.allergies.isEmpty ? "None" : preferences.allergies.joined(
            separator: ", "
        )
        let dislikedStr = preferences.dislikedIngredients.isEmpty ? "None" : preferences.dislikedIngredients.joined(
            separator: ", "
        )
        let favoritesStr = preferences.favoriteIngredients.isEmpty ? "No specific favorites recorded" : preferences.favoriteIngredients.joined(
            separator: ", "
        )
        let tagsStr = preferences.favoriteTags.isEmpty ? "None" : preferences.favoriteTags.joined(
            separator: ", "
        )
            
        // Determine the max time: Use the context override, or fallback to preferences, or default to 60.
        let maxTime = context.timeOverride ?? preferences.maxPrepTimeMinutes ?? 60
        
        let catalogString = availableRecipes.map { r in
            let totalTime = r.prepTime.totalMinutes
            return "[\(r.id.uuidString)] \(r.title) (\(r.type.rawValue), \(totalTime)m): \(r.summary)"
        }.joined(separator: "\n")
            
        // 2. Build the Prompt
        let prompt = """
            You are an expert culinary assistant inside the iPad app KitchenOS. 
            Select the THREE BEST recipe from the user's provided catalog that fits their current request and baseline preferences.
            
            USER BASELINE:
            - Skill Level: \(preferences.cookingSkillLevel.rawValue)
            - Diet: \(preferences.dietaryPreferences.rawValue)
            - Allergies: \(allergiesStr) (STRICT: DO NOT INCLUDE THESE)
            - Dislikes: \(dislikedStr)
            - Favorite Ingredients: \(favoritesStr)
            - Favorite Styles/Tags: \(tagsStr)
            \(preferences.targetDailyCalories != nil ? "- Target Daily Calories: \(preferences.targetDailyCalories!) kcal" : "")
            \(preferences.planLeftovers ? "- PREFERENCE: The user likes leftovers, so scale portions or suggest dishes that store well." : "")
            
            CURRENT REQUEST:
            - Meal Type: \(context.mealType.rawValue)
            - Max Total Time (Prep + Cook): \(maxTime) minutes
            \(context.vibe.isEmpty ? "" : "- Vibe/Style requested: \(context.vibe)")
            \(context.includedIngredients.isEmpty ? "" : "- MUST INCLUDE: \(context.includedIngredients)")
            
            CONTEXT:
            - UPCOMING MEALS (DO NOT RECOMMEND): \(upcomingTitles.isEmpty ? "None" : upcomingTitles)
            - RECENTLY EATEN: \(pastTitles.isEmpty ? "No history" : pastTitles)
            
            CRITICAL INSTRUCTION: Analyze the "RECENTLY EATEN" list. Do not recommend a meal they just had a few days ago unless the "Must Include" specifically overrides it. Aim to provide variety while respecting their taste profile.
            
            USER'S RECIPE CATALOG:
            \(catalogString)
            
            Return a JSON ARRAY containing EXACTLY 3 objects matching this structure:
            [
              {
                "recipeId": "String, exact UUID from the catalog",
                "reason": "String, a 1-2 sentence appetizing explanation of why this fits perfectly"
              }
            ]            
            """
                    
        let response = try await model.generateContent(prompt)
        
        guard let text = response.text, let data = text.data(using: .utf8) else {
            throw NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from AI."])
        }
        
        return try JSONDecoder().decode([LibraryRecommendationResult].self, from: data)    }
}

