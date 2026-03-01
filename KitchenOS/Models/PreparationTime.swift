//
//  PreparationTime.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 2/16/26.
//
import Foundation

struct PreparationTime: Codable, Sendable {
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
