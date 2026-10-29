//
//  AIProvider.swift
//  KitchenOS
//
//  Which model backs recipe extraction and library recommendations, all free
//  except Gemini:
//  - `.automatic` uses the best the device has: Apple's on-device model, then
//    the Mac if one is set up, then plain rules that work on every device.
//  - `.local` always talks to an Ollama server, typically on the user's Mac.
//  - `.gemini` is the original paid Google API path.
//
//  Stored in UserDefaults so the non-View AIService can read it directly, and
//  bound via @AppStorage in Settings — same pattern as RecipeLanguage.
//

import Foundation

enum AIProvider: String, CaseIterable, Identifiable {
    case automatic
    case local
    case gemini

    var id: String { rawValue }

    static let storageKey = "aiProvider"

    static var current: AIProvider {
        let raw = UserDefaults.standard.string(forKey: storageKey) ?? AIProvider.automatic.rawValue
        return AIProvider(rawValue: raw) ?? .automatic
    }

    var displayName: String {
        switch self {
        case .automatic: return "Automatic (On Device)"
        case .local:  return "Your Mac (Ollama)"
        case .gemini: return "Google Gemini"
        }
    }
}

// `nonisolated` so OllamaClient (also nonisolated) can read it; UserDefaults is thread-safe.
nonisolated enum OllamaSettings {
    static let serverURLKey = "ollamaServerURL"
    static let modelKey = "ollamaModel"

    // localhost works from the simulator; an iPad needs the Mac's address,
    // e.g. http://my-mac.local:11434 or its Tailscale address.
    static let defaultServerURL = "http://localhost:11434"
    static let defaultModel = "qwen3-vl:30b"

    /// The entered server, or localhost when the field is empty.
    static var serverURL: String {
        let entered = UserDefaults.standard.string(forKey: serverURLKey)?.trimmingCharacters(in: .whitespaces) ?? ""
        return entered.isEmpty ? defaultServerURL : entered
    }

    static var model: String {
        UserDefaults.standard.string(forKey: modelKey) ?? defaultModel
    }

    /// Whether the user entered a server, so `.automatic` should try it. The
    /// localhost default only makes sense in the simulator, so it doesn't count.
    static var isConfigured: Bool {
        serverURL != defaultServerURL
    }
}
