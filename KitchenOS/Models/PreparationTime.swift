//
//  PreparationTime.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 2/16/26.
//
import Foundation

// `nonisolated` because the file's default actor isolation (MainActor) would
// otherwise isolate the Codable conformance, which SwiftData encodes off the main
// actor — a warning today, an error under the Swift 6 language mode.
nonisolated struct PreparationTime: Codable, Sendable {
    var prepTime: Int
    var cookingTime: Int
    
    init(prepTime: Int = 0, cookingTime: Int = 0) {
        self.prepTime = prepTime
        self.cookingTime = cookingTime
    }
    
    var totalMinutes: Int {
        return prepTime + cookingTime
    }
}
