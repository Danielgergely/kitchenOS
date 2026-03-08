//
//  MostCookedWidget.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/8/26.
//
import SwiftUI

struct MostCookedWidget: View {
    let recipes: [Recipe]
    
    var topRecipe: Recipe? {
        recipes.max(by: { $0.timesCooked < $1.timesCooked })
    }
    
    var body: some View {
        DashboardCard(color: .pink) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Most Cooked", systemImage: "flame.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.pink)
                        .textCase(.uppercase)
                    
                    if let top = topRecipe, top.timesCooked > 0 {
                        Text(top.title)
                            .font(.headline)
                            .lineLimit(2)
                        
                        Spacer()
                        
                        Text("Cooked \(top.timesCooked) times")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Cook more meals to see your favorites here!")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
                .padding(.vertical, 2)
                
                Spacer()
                
                if let top = topRecipe, top.timesCooked > 0, let data = top.image, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .frame(maxHeight: .infinity)
        }
    }
}
