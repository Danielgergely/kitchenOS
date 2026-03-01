//
//  ConfigService.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/1/26.
//
import Foundation

struct Secrets {
    static var googleApiKey: String {
        // This looks into the Info.plist we just edited
        guard let key = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_API_KEY") as? String else {
            fatalError("ApiKey not found in Info.plist. Check your .xcconfig file!")
        }
        return key
    }
}
