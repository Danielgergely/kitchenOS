//
//  ShoppingListWidget.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/8/26.
//
import SwiftUI

struct ShoppingListWidget: View {
    let items: [ShoppingItem]
    let size: WidgetSize
    
    var body: some View {
        BaseWidgetLayout(
            size: size,
            color: .orange,
            icon: "cart",
            title: "Shopping",
            subtitle: items.isEmpty ? "All caught up!" : "\(items.count) items"
        ) {
            // Main Content
            ZStack {
                Circle().fill(Color.orange.opacity(0.1))
                Image(systemName: "cart")
                    .font(.title)
                    .foregroundStyle(.orange)
            }
            .overlay(alignment: .topTrailing) {
                // Show the red badge if we have items
                if !items.isEmpty {
                    Text("\(items.count)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Color.red)
                        .clipShape(Circle())
                        .offset(x: 4, y: -4)
                }
            }
        } extraStats: {
            // Extra Stats
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    // Show more items if it's a large widget, fewer if small
                    let displayCount = size == .small ? 2 : 4
                    ForEach(items.prefix(displayCount)) { item in
                        Label(item.name, systemImage: "circle")
                            .lineLimit(1)
                    }
                }
                .font(size == .large ? .subheadline : .caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}
