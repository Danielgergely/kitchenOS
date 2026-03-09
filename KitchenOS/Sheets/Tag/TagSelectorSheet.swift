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
                    ContentUnavailableView(
                        "No Tags",
                        systemImage: "tag.slash",
                        description: Text("Create your first tag to get started.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(allTags) { tag in
                            let isSelected = selectedTags.contains(where: { $0.id == tag.id })
                            
                            Button {
                                withAnimation(.snappy) {
                                    if isSelected {
                                        selectedTags.removeAll(where: { $0.id == tag.id })
                                    } else {
                                        selectedTags.append(tag)
                                    }
                                }
                            } label: {
                                HStack {
                                    TagPill(tag: tag, isSelected: isSelected)
                                    
                                    Spacer()
                                    
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(.blue)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteTag(tag)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    } footer: {
                        Text("Swipe left on any tag to delete it permanently.")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Select Tags")
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
    
    private func deleteTag(_ tag: Tag) {
        withAnimation {
            selectedTags.removeAll(where: { $0.id == tag.id })
            modelContext.delete(tag)
        }
    }
}
