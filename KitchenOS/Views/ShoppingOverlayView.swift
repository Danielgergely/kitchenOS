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
    @State private var exportResult: RemindersService.ExportResult?
    @State private var showExportAlert = false
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
        .opacity(items.isEmpty ? 0.1 : 0.6)
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
                    Task {
                        let result = await RemindersService.shared.exportToReminders(items: items)
                        exportResult = result
                        showExportAlert = true
                    }
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
        .alert(exportAlertTitle, isPresented: $showExportAlert) {
            Button("OK", role: .cancel) {}
            if exportResult == .accessDenied {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        } message: {
            Text(exportAlertMessage)
        }
    }

    private var exportAlertTitle: String {
        switch exportResult {
        case .success:      return "Exported"
        case .empty:        return "Nothing to Export"
        case .accessDenied: return "Reminders Access Needed"
        case .failure:      return "Export Failed"
        case .none:         return ""
        }
    }

    private var exportAlertMessage: String {
        switch exportResult {
        case .success(let count, let listName):
            return "Added \(count) item\(count == 1 ? "" : "s") to your \"\(listName)\" list in Reminders."
        case .empty:
            return "Your shopping list is empty."
        case .accessDenied:
            return "Allow access to Reminders in Settings to export your shopping list."
        case .failure(let message):
            return message
        case .none:
            return ""
        }
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
