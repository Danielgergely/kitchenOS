//
//  SmartInstructionsText.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/21/26.
//
import SwiftUI

import SwiftUI

struct SmartInstructionText: View {
    let step: String
    let ingredients: [Ingredient]
    
    var body: some View {
        // 1. Match Identification (Optimized for overlaps and length)
        var matches: [(range: Range<String.Index>, ingredient: Ingredient)] = []
        let sortedIngredients = ingredients.sorted { $0.name.count > $1.name.count }
        
        for ingredient in sortedIngredients {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: ingredient.name))\\b"
            var searchRange = step.startIndex..<step.endIndex
            
            while let range = step.range(of: pattern, options: [.regularExpression, .caseInsensitive], range: searchRange) {
                if !matches.contains(where: { $0.range.overlaps(range) }) {
                    matches.append((range: range, ingredient: ingredient))
                }
                searchRange = range.upperBound..<step.endIndex
            }
        }
        
        let finalMatches = matches.sorted(by: { $0.range.lowerBound < $1.range.lowerBound })
        
        // 2. Build the Styled AttributedString
        var attributedString = AttributedString(step)
        
        for match in finalMatches.reversed() {
            if let rangeInAttributed = attributedString.range(of: step[match.range]) {
                
                // --- STYLE THE "CHIP" ---
                // We add a tiny bit of padding by adding spaces around the name inside the styling
                attributedString[rangeInAttributed].foregroundColor = .blue
                attributedString[rangeInAttributed].font = .body.bold()
                
                // This creates the subtle blue highlight behind the text
                attributedString[rangeInAttributed].backgroundColor = Color.blue.opacity(0.15)
                
                // --- CREATE THE SUFFIX ---
                let suffix = " (\(match.ingredient.amount.formatted()) \(match.ingredient.unit.rawValue))"
                var amountString = AttributedString(suffix)
                amountString.foregroundColor = .secondary
                amountString.font = .caption2.bold()
                
                // Insert the amount suffix
                attributedString.insert(amountString, at: rangeInAttributed.upperBound)
            }
        }
        
        return Text(attributedString)
            .lineSpacing(8)
    }
}
