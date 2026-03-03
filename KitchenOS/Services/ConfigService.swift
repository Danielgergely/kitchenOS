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
}
