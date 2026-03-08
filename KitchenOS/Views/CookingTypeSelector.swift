//
//  CookingTypeSelector.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/8/26.
//
import SwiftUI

struct CookingTypeSelector: View {
    @Binding var selection: CookingType
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(CookingType.allCases, id: \.self) { type in
                Button {
                    withAnimation(.snappy) {
                        selection = type
                    }
                } label: {
                    Text(type.rawValue.replacingOccurrences(of: " Meal", with: ""))
                        .font(.caption2.bold())
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                        .frame(maxWidth: .infinity)
                        .background(selection == type ? Color.accentColor : Color(uiColor: .secondarySystemFill))
                        .foregroundStyle(selection == type ? .white : .primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
