import SwiftUI
import GoogleGenerativeAI

// Moving these structs here keeps the networking data separate from your UI!
struct ExtractedRecipe: Codable {
    let title: String?
    let summary: String?
    let instructions: String?
    let prepTime: Int?
    let cookTime: Int?
    let ingredients: [ExtractedIngredient]?
}

struct ExtractedIngredient: Codable {
    let name: String?
    let amount: Double?
    let unit: String?
}

class AIService {
    // A shared instance so we can easily call it from anywhere
    static let shared = AIService()
    
    // The list of models to rotate through!
    private let fallbackModels = [
        "gemini-2.5-flash",
        "gemini-3-flash",
        "gemini-2.5-flash-lite"
    ]
    
    // Notice this function is `async throws` and RETURNS the ExtractedRecipe
    func extractRecipe(from image: UIImage) async throws -> ExtractedRecipe {
        let config = GenerationConfig(responseMIMEType: "application/json")
        let apiKey = Secrets.googleApiKey
        
        let prompt = """
        Extract the recipe from this image. 
        Return a JSON object with the following keys:
        - title (String)
        - summary (String, a short 1-2 sentence description)
        - instructions (String, formatted step-by-step with line breaks)
        - prepTime (Int, minutes only)
        - cookTime (Int, minutes only)
        - ingredients (Array of objects with 'name' (String), 'amount' (Double), 'unit' (String, use exact words like piece, g, ml, cup, tbsp, tsp, pinch))
        """
        
        var lastError: Error?
        
        // Loop through our models one by one
        for modelName in fallbackModels {
            do {
                print("🤖 Attempting AI extraction with model: \(modelName)")
                let model = GenerativeModel(name: modelName, apiKey: apiKey, generationConfig: config)
                let response = try await model.generateContent(prompt, image)
                
                guard let text = response.text, let data = text.data(using: .utf8) else {
                    print("⚠️ Could not read response from \(modelName). Trying next model...")
                    continue
                }
                
                print("🧠 Success with \(modelName)!")
                
                let extracted = try JSONDecoder().decode(ExtractedRecipe.self, from: data)
                return extracted
                
            } catch {
                print("❌ Model \(modelName) failed (likely rate limit): \(error.localizedDescription)")
                lastError = error
            }
        }
        
        throw lastError ?? NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "All fallback models failed."])
    }
}
