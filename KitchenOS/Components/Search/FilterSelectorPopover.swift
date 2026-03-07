//
//  FilterSelectorPopover.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/7/26.
//
import SwiftUI
import SwiftData

struct FilterSelectorPopover: View {
    var selectedTags: Binding<[Tag]>?
    var selectedFoodTypes: Binding<[FoodType]>?
    
    @Query(sort: \Tag.name) private var allTags: [Tag]
    
    var body: some View {
        NavigationStack {
            List {
                // Food types
                if let selectedFoodTypesBinding = selectedFoodTypes {
                    Section("Food Types") {
                        ForEach(FoodType.allCases, id: \.self) { type in
                            FoodTypeRow(type: type, selectedFoodTypes: selectedFoodTypesBinding)
                        }
                    }
                }

                // Tags
                if let selectedTagsBinding = selectedTags {
                    Section("Tags") {
                        if allTags.isEmpty {
                            Text("No tags available.").foregroundStyle(.secondary)
                        } else {
                            ForEach(allTags) { tag in
                                TagRow(tag: tag, selectedTags: selectedTagsBinding)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationCompactAdaptation(.popover)
        .frame(minWidth: 300, minHeight: 400)
    }
}
private struct FoodTypeRow: View {
    let type: FoodType
    @Binding var selectedFoodTypes: [FoodType]

    init(type: FoodType, selectedFoodTypes: Binding<[FoodType]>) {
        self.type = type
        self._selectedFoodTypes = selectedFoodTypes
    }

    var isSelected: Bool { selectedFoodTypes.contains(type) }

    var body: some View {
        Button {
            withAnimation {
                if isSelected {
                    selectedFoodTypes.removeAll { $0 == type }
                } else {
                    selectedFoodTypes.append(type)
                }
            }
        } label: {
            HStack {
                Image(type.info.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                Text(type.info.name)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark").foregroundStyle(.tint)
                }
            }
        }
        .foregroundStyle(.primary)
    }
}

private struct TagRow: View {
    let tag: Tag
    @Binding var selectedTags: [Tag]

    init(tag: Tag, selectedTags: Binding<[Tag]>) {
        self.tag = tag
        self._selectedTags = selectedTags
    }

    var isSelected: Bool { selectedTags.contains(where: { $0.id == tag.id }) }

    var body: some View {
        Button {
            withAnimation {
                if isSelected {
                    selectedTags.removeAll(where: { $0.id == tag.id })
                } else {
                    selectedTags.append(tag)
                }
            }
        } label: {
            HStack {
                Image(tag.icon)
                    .foregroundStyle(tag.color.displayColor)
                Text(tag.name)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
        .foregroundStyle(.primary)
    }
}

