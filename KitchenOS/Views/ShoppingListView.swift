//
//  ShoppingListView.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/3/26.
//
import SwiftUI
import SwiftData

struct ShoppingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShoppingItem.createdAt, order: .forward) private var items: [ShoppingItem]
    
    private var allSelected: Bool {
        !items.isEmpty && items.allSatisfy { $0.isChecked }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if items.isEmpty {
                    ContentUnavailableView(
                        "Empty List",
                        systemImage: "cart",
                        description: Text("Add ingredients from your recipes to see them here.")
                    )
                } else {
                    Section {
                        ForEach(items) { item in
                            HStack(spacing: 16) {
                                Button {
                                    item.isChecked.toggle()
                                    HapticManager.impact(style: .light)
                                } label: {
                                    Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(item.isChecked ? .green : .secondary)
                                        .font(.title2)
                                }
                                .buttonStyle(.plain)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.headline)
                                        .strikethrough(item.isChecked)
                                        .foregroundStyle(item.isChecked ? .secondary : .primary)
                                    
                                    Text("\(item.amount, format: .number) \(item.unit.rawValue)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: deleteItems)
                    } header: {
                        Text("\(items.count) Items")
                    }
                }
            }
            .navigationTitle("Shopping List")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if !items.isEmpty {
                        Button {
                            toggleSelectAll()
                        } label: {
                            Label(allSelected ? "Deselect All" : "Select All",
                                  systemImage: allSelected ? "checkmark.circle.badge.xmark" : "checkmark.circle.badge.questionmark")
                        }
                        Button {
                            Task {
                                await RemindersService.shared.exportToReminders(items: items)
                                HapticManager.notification(type: .success)
                            }
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(role: .destructive) {
                            clearCheckedItems()
                        } label: {
                            Label("Clear Checked", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
    private func toggleSelectAll() {
            let shouldSelect = !allSelected
            withAnimation {
                for item in items {
                    item.isChecked = shouldSelect
                }
            }
            HapticManager.impact(style: .medium)
        }
    
    private func deleteItems(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
    }
    
    private func clearCheckedItems() {
        withAnimation {
            for item in items where item.isChecked {
                modelContext.delete(item)
            }
        }
    }
}
