//
//  WidgetSelectorSheet.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/13/26.
//
import SwiftUI

struct WidgetSelectorSheet: View {
    @Environment(\.dismiss) var dismiss
    
    var onSelect: (DashboardWidget, WidgetSize) -> Void
    
    @State private var selectedSize: WidgetSize = .small
    
    var body: some View {
        NavigationStack {
            List {
                // Size Picker Section
                Section {
                    Picker("Size", selection: $selectedSize) {
                        Text("Small (1x1)").tag(WidgetSize.small)
                        Text("Medium (2x1)").tag(WidgetSize.medium)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Widget Size")
                } footer: {
                    if selectedSize == .medium {
                        Text("Medium widgets will span two columns. If placed at the edge, they will automatically default to small.")
                    }
                }
                
                // Widget List Section
                Section("Available Widgets") {
                    ForEach(DashboardWidget.allCases) { widget in
                        Button {
                            onSelect(widget, selectedSize)
                            dismiss()
                        } label: {
                            HStack {
                                Label(widget.rawValue, systemImage: widget.icon)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.tint)
                                    .opacity(0.5)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Widget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
