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
    
    // Optional bindings for filtering
    var selectedTags: Binding<[Tag]>? = nil
    var selectedFoodTypes: Binding<[FoodType]>? = nil
    
    @State private var isSearchExpanded = false
    @FocusState private var isFocused: Bool
    @State private var showingFilterPopover = false
    
    var body: some View {
        HStack(spacing: 12) {
            
            // Filter pills
            if hasSelectedFilters {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if let foodTypes = selectedFoodTypes?.wrappedValue {
                            ForEach(foodTypes, id: \.self) { type in
                                FilterPill(title: type.info.name, icon: type.info.icon, isSystemImage: false, color: .orange) {
                                    withAnimation {
                                        selectedFoodTypes?.wrappedValue.removeAll(where: { $0 == type })
                                    }
                                }
                            }
                        }
                        
                        if let tags = selectedTags?.wrappedValue {
                            ForEach(tags) { tag in
                                FilterPill(title: tag.name, icon: tag.icon, isSystemImage: false, color: tag.color.displayColor) {
                                    withAnimation {
                                        selectedTags?.wrappedValue.removeAll(where: { $0.id == tag.id })
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(height: 36)
            }
            
            // Search textfield
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
            
            // Filter icons
            HStack(spacing: 12) {
                if selectedTags != nil || selectedFoodTypes != nil {
                    // Filter button
                    Button {
                        showingFilterPopover = true
                    } label: {
                        Image(systemName: hasSelectedFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(hasSelectedFilters ? Color.accentColor : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showingFilterPopover) {
                        FilterSelectorPopover(
                            selectedTags: selectedTags,
                            selectedFoodTypes: selectedFoodTypes
                        )
                    }
                }
                
                // Search button
                Button {
                    if isSearchExpanded {
                        if !text.isEmpty {
                            text = ""
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isSearchExpanded = false
                                isFocused = false
                            }
                        }
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isSearchExpanded = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            isFocused = true
                        }
                    }
                } label: {
                    Image(systemName: isSearchExpanded ? "xmark.circle.fill" : "magnifyingglass")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
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
    
    private var hasSelectedFilters: Bool {
        let hasTags = !(selectedTags?.wrappedValue.isEmpty ?? true)
        let hasTypes = !(selectedFoodTypes?.wrappedValue.isEmpty ?? true)
        return hasTags || hasTypes
    }
}

