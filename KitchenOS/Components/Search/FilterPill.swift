//
//  FilterPill.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/7/26.
//
import SwiftUI

struct FilterPill: View {
    let title: String
    let icon: String
    let isSystemImage: Bool
    let color: Color
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            if isSystemImage {
                Image(systemName: icon)
            } else {
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
            }
            Text(title)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .padding(4)
                    .background(Color.black.opacity(0.1))
                    .clipShape(Circle())
            }
            .padding(.leading, 2)
        }
        .font(.caption.bold())
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}
