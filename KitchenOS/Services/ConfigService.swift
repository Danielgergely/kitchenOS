//
//  ConfigService.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/1/26.
//
import Foundation

struct Secrets {
    static var googleApiKey: String {
        // This looks into the Info.plist row you just created
        guard let key = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_API_KEY") as? String else {
            fatalError("ApiKey not found in Info.plist. Check your .xcconfig mapping!")
        }
        return key
    }
    // supabase stuff
    static var supabaseURL: URL {
        guard let domainString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              // Manually prepend the https:// here!
              let url = URL(string: "https://\(domainString)") else {
            fatalError("Supabase URL not found or invalid in Info.plist.")
        }
        return url
    }
    
    static var supabasePublishableKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String else {
            fatalError("Supabase Publishable Key not found in Info.plist.")
        }
        return key
    }
    
    static var adminPassword: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "ADMIN_PASSWORD") as? String else {
            fatalError("Admin Password not found in Info.plist.")
        }
        return key
    }
}
