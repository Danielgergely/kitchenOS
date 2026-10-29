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
        "gemini-2.5-flash-lite"
    ]
    
    func getRecipeExtractionAIPrompt(extractFromText: String, tagList: String) -> String {
        let language = RecipeLanguage.current.resolvedLanguageName
        return """
        You are a recipe extraction assistant.
        Extract the recipe from \(extractFromText).

        LANGUAGE: Output ALL text — title, summary, instructions, and every ingredient
        name — in \(language). If the source recipe is written in another language,
        translate it into \(language). Be consistent: never mix languages within the result.

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
        
        switch AIProvider.current {
        case .automatic:
            return try await extractOnDevice(image: image, availableTags: availableTags)
        case .local:
            return try await extractLocally(image: image, availableTags: availableTags)
        case .gemini:
            let prompt = getRecipeExtractionAIPrompt(
                extractFromText: "this image",
                tagList: tagList
            )
            return try await callLLM(prompt: prompt, content: image)
        }
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

        // Primary path: parse embedded schema.org JSON-LD. Free, instant, on-device,
        // works without any API call. Most recipe sites provide it.
        // Detached so regexing a whole page never blocks the main actor.
        let structuredResult = await Task.detached(priority: .userInitiated) {
            RecipeJSONLDExtractor.extract(fromHTML: htmlContent)
        }.value

        if let structured = structuredResult {
            print("✅ Extracted recipe from schema.org JSON-LD — no API call needed.")
            return structured
        }

        // Fallback: the page has no structured data, so use the LLM.
        print("ℹ️ No JSON-LD found — falling back to AI extraction.")
        if AIProvider.current == .gemini {
            let prompt = getRecipeExtractionAIPrompt(
                extractFromText: "the provided website HTML",
                tagList: tagList
            )
            return try await callLLM(prompt: prompt, content: htmlContent)
        }

        // Local models' context can't take a whole raw page; send its text.
        let pageText = await Task.detached(priority: .userInitiated) {
            WebPageText.readableText(fromHTML: htmlContent)
        }.value
        switch AIProvider.current {
        case .automatic:
            return try await extractOnDevice(pageText: pageText, availableTags: availableTags)
        case .local, .gemini:
            return try await extractLocally(pageText: pageText, availableTags: availableTags)
        }
    }

    // MARK: - Automatic (on device first)

    /// The best free option this device has: Apple's on-device model, then the
    /// Mac if one is set up, then plain rules — which always work, offline.
    private func extractOnDevice(image: UIImage, availableTags: [String]) async throws -> ExtractedRecipe {
        let lines = try await TextRecognizer.lines(in: image)
        return try await extractOnDevice(
            text: lines.joined(separator: "\n"),
            lines: lines,
            availableTags: availableTags,
            viaMac: { try await self.extractLocally(image: image, availableTags: availableTags) }
        )
    }

    private func extractOnDevice(pageText: String, availableTags: [String]) async throws -> ExtractedRecipe {
        let lines = pageText.components(separatedBy: "\n").filter { !$0.hasPrefix("og:image:") }
        var recipe = try await extractOnDevice(
            text: lines.joined(separator: "\n"),
            lines: lines,
            availableTags: availableTags,
            viaMac: { try await self.extractLocally(pageText: pageText, availableTags: availableTags) }
        )
        if recipe.imageUrl == nil, let image = pageText.firstMatch(of: /^og:image: (.+)$/.anchorsMatchLineEndings()) {
            recipe = recipe.withImageURL(String(image.1))
        }
        return recipe
    }

    private func extractOnDevice(
        text: String,
        lines: [String],
        availableTags: [String],
        viaMac: () async throws -> ExtractedRecipe
    ) async throws -> ExtractedRecipe {
        if OnDeviceModel.isAvailable {
            do {
                print("📱 Extracting with Apple's on-device model")
                return try await OnDeviceModel.extractRecipe(fromText: text, availableTags: availableTags)
            } catch {
                print("⚠️ On-device model failed: \(error.localizedDescription) — trying the next option.")
            }
        }
        if OllamaSettings.isConfigured {
            do {
                return try await viaMac()
            } catch {
                print("⚠️ Mac extraction failed: \(error.localizedDescription) — falling back to rules.")
            }
        }
        print("📝 Parsing the text with rules")
        return RecipeTextParser.parse(lines: lines)
    }

    // MARK: - Local (Ollama)

    private func extractLocally(image: UIImage, availableTags: [String]) async throws -> ExtractedRecipe {
        // Large enough to keep small print legible, small enough to keep the
        // request (and the model's image tokens) modest.
        guard let jpeg = image.optimizedForDatabase(maxDimension: 1600, compressionQuality: 0.85) else {
            throw NSError(
                domain: "AIService",
                code: -4,
                userInfo: [NSLocalizedDescriptionKey: "Couldn't prepare the photo for extraction."]
            )
        }
        let prompt = getRecipeExtractionAIPrompt(extractFromText: "this image", tagList: tagListText(availableTags))
        return try await extractLocally(prompt: prompt, images: [jpeg], availableTags: availableTags, allowsImageURL: false)
    }

    private func extractLocally(pageText: String, availableTags: [String]) async throws -> ExtractedRecipe {
        let prompt = getRecipeExtractionAIPrompt(
            extractFromText: "the website text below (the og:image line, if present, is the main recipe image)",
            tagList: tagListText(availableTags)
        ) + "\n\nWEBSITE TEXT:\n" + pageText
        return try await extractLocally(prompt: prompt, availableTags: availableTags, allowsImageURL: true)
    }

    private func tagListText(_ tags: [String]) -> String {
        tags.isEmpty ? "None available" : tags.joined(separator: ", ")
    }

    private func extractLocally(prompt: String, images: [Data] = [], availableTags: [String], allowsImageURL: Bool) async throws -> ExtractedRecipe {
        let client = try OllamaClient.fromSettings()
        print("🖥️ Extracting with local model \(client.model) at \(client.baseURL)")
        let data = try await client.chatJSON(
            prompt: prompt,
            images: images,
            schema: recipeSchema(availableTags: availableTags, allowsImageURL: allowsImageURL)
        )
        return try JSONDecoder().decode(ExtractedRecipe.self, from: data)
    }

    /// JSON schema for ExtractedRecipe. Ollama constrains generation to it, so
    /// the type, units and tags can only be values the app understands. A photo
    /// has no image URL to report and models invent one if allowed, so the field
    /// is left out for photos (a `"null"`-only type makes Ollama generate forever).
    private func recipeSchema(availableTags: [String], allowsImageURL: Bool) -> [String: Any] {
        let string: [String: Any] = ["type": "string"]
        let integer: [String: Any] = ["type": "integer"]
        let tagItem: [String: Any] = availableTags.isEmpty ? string : ["type": "string", "enum": availableTags]
        let ingredient: [String: Any] = [
            "type": "object",
            "properties": [
                "name": string,
                "amount": ["type": "number"],
                "unit": ["type": "string", "enum": Unit.allCases.map { $0.rawValue }],
            ],
            "required": ["name", "amount", "unit"],
        ]
        var properties: [String: Any] = [
            "title": string,
            "summary": string,
            "instructions": string,
            "prepTime": integer,
            "cookTime": integer,
            "type": ["type": "string", "enum": FoodType.allCases.map { $0.rawValue }],
            "tags": ["type": "array", "items": tagItem],
            "ingredients": ["type": "array", "items": ingredient],
        ]
        var required = ["title", "summary", "instructions", "prepTime", "cookTime",
                        "type", "tags", "ingredients"]
        if allowsImageURL {
            properties["imageUrl"] = ["type": ["string", "null"]]
            required.append("imageUrl")
        }
        return ["type": "object", "properties": properties, "required": required]
    }

    /// JSON schema for exactly three recommendations whose IDs must come from the catalog.
    private func recommendationSchema(recipeIds: [String]) -> [String: Any] {
        [
            "type": "array",
            "minItems": 3,
            "maxItems": 3,
            "items": [
                "type": "object",
                "properties": [
                    "recipeId": ["type": "string", "enum": recipeIds],
                    "reason": ["type": "string"],
                ],
                "required": ["recipeId", "reason"],
            ],
        ]
    }
    
    func recommendFromLibrary(context: RecommendationContext, preferences: UserPreferences, upcomingMeals: [PlannedMeal], pastMeals: [PlannedMeal], availableRecipes: [Recipe]) async throws -> [LibraryRecommendationResult] {
        
        guard !availableRecipes.isEmpty else {
            throw NSError(
                domain: "AIService",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "No recipes in library."]
            )
        }
            
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
            You are an expert culinary assistant inside the iPad app MealOS.
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
                    
        func ruleBasedPicks() -> [LibraryRecommendationResult] {
            RuleBasedRecommender.recommend(
                context: context,
                preferences: preferences,
                upcomingMeals: upcomingMeals,
                pastMeals: pastMeals,
                availableRecipes: availableRecipes
            )
        }
        let schema = recommendationSchema(recipeIds: availableRecipes.map { $0.id.uuidString })

        let data: Data
        switch AIProvider.current {
        case .automatic:
            // Apple's on-device model can't hold a whole recipe catalog in its
            // context, so use the Mac if one is set up, otherwise plain rules.
            guard OllamaSettings.isConfigured else { return ruleBasedPicks() }
            do {
                data = try await OllamaClient.fromSettings().chatJSON(prompt: prompt, schema: schema)
            } catch {
                print("⚠️ Mac recommendations failed: \(error.localizedDescription) — falling back to rules.")
                return ruleBasedPicks()
            }
        case .local:
            data = try await OllamaClient.fromSettings().chatJSON(prompt: prompt, schema: schema)
        case .gemini:
            let model = GenerativeModel(
                name: "gemini-3-flash-preview",
                apiKey: Secrets.googleApiKey,
                generationConfig: config
            )
            let response = try await model.generateContent(prompt)
            guard let text = response.text, let geminiData = text.data(using: .utf8) else {
                throw NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from AI."])
            }
            data = geminiData
        }

        return try JSONDecoder().decode([LibraryRecommendationResult].self, from: data)
    }
}

