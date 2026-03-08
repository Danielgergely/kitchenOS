//
//  ShoppingListWidget.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/8/26.
//
import SwiftUI

struct ShoppingListWidget: View {
    let items: [ShoppingItem]
    
    var body: some View {
        DashboardCard(color: .orange) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Shopping", systemImage: "cart")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                    Spacer()
                    Text("\(items.count)")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
                
                Spacer()
                
                if items.isEmpty {
                    Text("All caught up!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(items.prefix(2)) { item in
                            Label(item.name, systemImage: "circle")
                                .lineLimit(1)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
}
