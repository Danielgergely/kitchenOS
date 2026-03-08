//
//  TotalRecipesWidget.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/8/26.
//
import SwiftUI

struct TotalRecipesWidget: View {
    let recipeCount: Int
    
    var body: some View {
        DashboardCard(color: .indigo) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "book.pages.fill")
                    .font(.title2)
                    .foregroundStyle(.indigo)
                
                Spacer()
                
                Text("\(recipeCount)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                
                Text("Total Recipes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
