//
//  MostCookedWidget.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/8/26.
//
import SwiftUI

struct MostCookedWidget: View {
    let recipes: [Recipe]
    let size: WidgetSize
    
    var topRecipe: Recipe? {
        recipes.max(by: { $0.timesCooked < $1.timesCooked })
    }
    
    var body: some View {
        BaseWidgetLayout(
            size: size,
            color: .pink,
            icon: "flame.fill",
            title: "Most Cooked",
            subtitle: topRecipe != nil ? "Cooked \(topRecipe!.timesCooked) times" : "Cook more meals!"
        ) {
            // Main Content
            if let top = topRecipe, top.timesCooked > 0, let data = top.image, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12).fill(Color.pink.opacity(0.1))
            }
        } extraStats: {
            // Extra Stats
            if let top = topRecipe, top.timesCooked > 0 {
                Text(top.title)
                    .font(size == .large ? .title2.bold() : .headline)
                    .lineLimit(size == .small ? 1 : 2)
            }
        }
    }
}
