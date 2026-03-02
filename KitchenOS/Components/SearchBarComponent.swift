//
//  SearchBarComponent.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/2/26.
//
import SwiftUI

struct ExpandableSearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search..."
    
    @State private var isSearchExpanded = false
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack {
            if isSearchExpanded {
                TextField(placeholder, text: $text)
                    .focused($isFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(uiColor: .secondarySystemFill))
                    .clipShape(Capsule())
                    .frame(maxWidth: 180)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .onSubmit {
                        if text.isEmpty {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isSearchExpanded = false
                            }
                        }
                    }
            }
            
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isSearchExpanded.toggle()
                    if isSearchExpanded {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            isFocused = true
                        }
                    } else {
                        text = ""
                        isFocused = false
                    }
                }
            } label: {
                Image(systemName: isSearchExpanded ? "xmark.circle.fill" : "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .onChange(of: isFocused) { oldValue, newValue in
            // Hide search bar if it lost focus (clicked out) AND the search box is empty
            if newValue == false && text.isEmpty {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isSearchExpanded = false
                }
            }
        }
    }
}
