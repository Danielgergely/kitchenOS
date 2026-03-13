//
//  BaseWidgetLayout.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/8/26.
//
import SwiftUI

struct BaseWidgetLayout<MainContent: View, ExtraStats: View>: View {
    let size: WidgetSize
    let color: Color
    let icon: String
    let title: String
    let subtitle: String?
    
    @ViewBuilder let mainContent: () -> MainContent
    @ViewBuilder let extraStats: () -> ExtraStats
    
    var body: some View {
        let isSmall = size == .small
        let dynamicLayout = isSmall ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
        
        dynamicLayout {
            // 1. Main Content
            mainContent()
                .frame(
                    width: isSmall ? 48 : (size == .large ? 140 : 100),
                    height: isSmall ? 48 : (size == .large ? 140 : 100)
                )
            
            // 2. Text & Stats
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: icon)
                    .font(.caption.bold())
                    .foregroundStyle(color)
                    .textCase(.uppercase)
                    .lineLimit(1)
                
                if isSmall { Spacer(minLength: 0) }
                
                extraStats()
                
                if let sub = subtitle {
                    Spacer(minLength: 0)
                    Text(sub)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        
        // Aspect ratios: Small = 1:1, Medium = 2.1:1, Large = 1:1
        //.aspectRatio(size == .medium ? 2.1 : 1.0, contentMode: .fit)
    }
}
