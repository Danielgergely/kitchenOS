//
//  TotalRecipesWidget.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/8/26.
//
import SwiftUI

struct TotalRecipesWidget: View {
    let recipeCount: Int
    let size: WidgetSize
    
    var body: some View {
        BaseWidgetLayout(
            size: size,
            color: .indigo,
            icon: "book.pages.fill",
            title: "Total Recipes",
            subtitle: "In your library"
        ) {
            // Main Content
            ZStack {
                Circle().fill(Color.indigo.opacity(0.1))
                Image(systemName: "book.pages.fill")
                    .font(.title)
                    .foregroundStyle(.indigo)
            }
        } extraStats: {
            // Extra Stats
            Text("\(recipeCount)")
                .font(.system(size: size == .large ? 48 : 36, weight: .bold, design: .rounded))
        }
    }
}
