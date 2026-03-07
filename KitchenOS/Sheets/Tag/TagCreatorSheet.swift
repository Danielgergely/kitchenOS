//
//  TagCreatorSheet.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/1/26.
//
import SwiftUI
import SwiftData

struct TagCreatorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var selectedColor: TagColor = .blue
    @State private var selectedIcon = "leaf.fill"
    
    let availableIcons = ["baguette", "birthday.cake", "bread", "cheese", "christmas", "cola", "cookies", "cooking.book", "crab", "croissant", "cupcake", "doughnut", "eggs", "fish", "flour", "french.fries", "fruit.apple", "fruit.avocado", "fruit.banana.peel", "fruit.banana", "fruit.cherry", "fruit.citrus", "fruit.coconut", "fruit.grapes", "fruit.kiwi", "fruit.melon", "fruit.orange.juice", "fruit.orange", "fruit.papaya", "fruit.peach", "fruit.pear", "fruit.pineapple", "fruit.plum", "fruit.pomegranate", "fruit.raspberry", "fruit.strawberry", "fruit.tomato", "fruit.watermelon", "gingerbread.house", "hamburger", "hazelnut", "hotdog", "ice.cream.cone", "ingredients", "list.view", "main.dish", "milk.bottle", "noodles", "nut", "octopus", "paella", "peanuts", "pizza", "prawn", "rack.of.lamb", "sausages", "spaghetti", "steak", "sunny.side.up.eggs", "sushi", "taco", "thanksgiving", "the.toast", "vegan.food", "vegetable.asparagus", "vegetable.beet", "vegetable.broccoli", "vegetable.cabbage", "vegetable.carrot", "vegetable.cauliflower", "vegetable.celery", "vegetable.chili.pepper", "vegetable.corn", "vegetable.cucumber", "vegetable.eggplant", "vegetable.garlic", "vegetable.leek", "vegetable.lettuce", "vegetable.mushroom", "vegetable.olive", "vegetable.onion", "vegetable.paprika", "vegetable.peas", "vegetable.potato", "vegetable.pumpkin", "vegetable.radish", "vegetable.soy", "vegetable.spinach", "vegetarian.food"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Tag Details") {
                    TextField("Tag Name", text: $name)
                    
                    HStack {
                        Text("Preview:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        TagPill(tag: Tag(name: name.isEmpty ? "New Tag" : name, icon: selectedIcon, color: selectedColor))
                    }
                }
                
                Section("Color") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(TagColor.allCases, id: \.self) { color in
                                Circle()
                                    .fill(color.displayColor)
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle().stroke(.primary, lineWidth: selectedColor == color ? 3 : 0)
                                    )
                                    .onTapGesture { selectedColor = color }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Image(icon)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(selectedIcon == icon ? Color.secondary.opacity(0.2) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onTapGesture { selectedIcon = icon }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("New Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let newTag = Tag(name: name, icon: selectedIcon, color: selectedColor)
                        modelContext.insert(newTag)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
