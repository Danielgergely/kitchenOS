//
//  TagSelectorSheet.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/1/26.
//
import SwiftUI
import SwiftData

struct TagSelectorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Binding var selectedTags: [Tag]
    
    @State private var showingCreator = false
    
    var body: some View {
        NavigationStack {
            List {
                if allTags.isEmpty {
                    Text("No tags yet. Create one!")
                        .foregroundStyle(.secondary)
                }
                
                ForEach(allTags) { tag in
                    Button {
                        if selectedTags.contains(where: { $0.id == tag.id }) {
                            selectedTags.removeAll(where: { $0.id == tag.id })
                        } else {
                            selectedTags.append(tag)
                        }
                    } label: {
                        HStack {
                            TagPill(tag: tag, isSelected: true)
                            Spacer()
                            if selectedTags.contains(where: { $0.id == tag.id }) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingCreator = true } label: { Image(systemName: "plus") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingCreator) {
                TagCreatorSheet()
            }
        }
    }
}
