//
//  ShoppingOverlayView.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/2/26.
//
import SwiftUI
import SwiftData

struct ShoppingOverlayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShoppingItem.createdAt) private var items: [ShoppingItem]
    
    @State private var isExpanded = false
    @Namespace private var animation
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                
                if isExpanded {
                    expandedView
                } else {
                    collapsedView
                }
            }
        }
        .padding(20)
    }
    
    // Collapsed Bubble
    private var collapsedView: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isExpanded = true
            }
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 64, height: 64)
                    .shadow(radius: 10)
                
                Image(systemName: "cart.fill")
                    .font(.title2)
                    .foregroundStyle(.primary.opacity(0.6))
                
                if !items.isEmpty {
                    Text("\(items.count)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(.blue, in: Circle())
                        .offset(x: 18, y: -18)
                }
            }
        }
        .matchedGeometryEffect(id: "cart", in: animation)
        .opacity(0.6)
    }
    
    // Expanded List
    private var expandedView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Shopping List")
                    .font(.headline)
                Spacer()
                Button {
                    withAnimation(.spring()) { isExpanded = false }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title2)
                }
            }
            .padding()
            
            // List of Items
            List {
                ForEach(items) { item in
                    HStack {
                        Text("\(item.amount, specifier: "%.1g") \(item.unit.rawValue) \(item.name)")
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                .onDelete(perform: deleteItems)
            }
            .listStyle(.plain)
            .frame(height: 300)
            
            // Footer Actions
            Divider()
            HStack(spacing: 20) {
                Button(role: .destructive, action: clearList) {
                    Label("Clear", systemImage: "trash")
                }
                
                Spacer()
                
                Button {
                    Task { await RemindersService.shared.exportToReminders(items: items) }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 320)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(radius: 20)
        .matchedGeometryEffect(id: "cart", in: animation)
    }
    
    private func deleteItems(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
    }
    
    private func clearList() {
        for item in items {
            modelContext.delete(item)
        }
        withAnimation { isExpanded = false }
    }
}
