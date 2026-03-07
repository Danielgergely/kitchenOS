import SwiftUI
import GoogleGenerativeAI

class AIService {
    // A shared instance so we can easily call it from anywhere
    static let shared = AIService()
    let config = GenerationConfig(responseMIMEType: "application/json")
    let apiKey = Secrets.googleApiKey
    let unitList = Unit.allCases.map { $0.rawValue }.joined(separator: ", ")
    let foodTypeList = FoodType.allCases.map { $0.rawValue }.joined(separator: ", ")
    
    // The list of models to rotate through!
    private let fallbackModels = [
        "gemini-2.5-flash",
        "gemini-3-flash",
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
                let model = GenerativeModel(name: modelName, apiKey: apiKey, generationConfig: config)
                let response = try await model.generateContent(prompt, content)
                
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
    
    // Notice this function is `async throws` and RETURNS the ExtractedRecipe
    func extractRecipeFromImage(from image: UIImage, availableTags: [String] = []) async throws -> ExtractedRecipe {
        let tagList = availableTags.isEmpty ? "None available" : availableTags.joined(separator: ", ")
        
        let prompt = getRecipeExtractionAIPrompt(extractFromText: "this image", tagList: tagList)
        
        // Convert the image to JPEG data and wrap as a Part for multimodal input
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            throw NSError(domain: "AI Service", code: -4, userInfo: [NSLocalizedDescriptionKey: "Failed to encode image data."])
        }
        
        return try await callLLM(prompt: prompt, content: image)
    }
    
    func extractRecipeFromURL(from url: URL, availableTags: [String] = []) async throws -> ExtractedRecipe {
        let tagList = availableTags.isEmpty ? "None available" : availableTags.joined(separator: ", ")
        // Fetch raw HTML
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "AI Service", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to load website. It might be blocked or offline."])
        }
        
        guard let htmlContent = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "AI Service", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to read website content."])
        }
        
        let prompt = getRecipeExtractionAIPrompt(extractFromText: "the provided website HTML", tagList: tagList)
        
        return try await callLLM(prompt: prompt, content: htmlContent)
    }
}

