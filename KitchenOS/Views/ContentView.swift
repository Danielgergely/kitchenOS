//
//  ContentView.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 2/16/26.
//
import SwiftUI

enum NavigationItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case calendar = "Week Plan"
    case recipes = "Recipes"
    case shopping = "Shopping List"
    case pantry = "Pantry"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .dashboard: return "house"
        case .calendar: return "calendar"
        case .recipes: return "book.pages"
        case .shopping: return "list.bullet.clipboard"
        case .pantry: return "cabinet"
        }
    }
}

struct ContentView: View {
    
    @State private var selectedItem: NavigationItem? = .calendar
    @State private var showSettings: Bool = false
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            NavigationSplitView {
                List(NavigationItem.allCases, selection: $selectedItem) { item in
                    NavigationLink(value: item) {
                        Label {
                            Text(item.rawValue)
                        } icon: {
                            Image(systemName: item.icon)
                        }
                    }
                }
                .navigationTitle("KitchenOS")
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
                .safeAreaInset(edge: .bottom) {
                    HStack {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                                .padding(12)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                }
            } detail: {
                if let selectedItem {
                    switch selectedItem {
                    case .dashboard:
                        ContentUnavailableView("Dashboard", systemImage: "house", description: Text("Coming soon"))
                    case .calendar:
                        WeekPlanView()
                            .navigationTitle("Week Plan")
                    case .recipes:
                        RecipeLibraryView()
                    case .shopping:
                        ShoppingListView()
                    case .pantry:
                        ContentUnavailableView("Pantry", systemImage: "cabinet", description: Text("Coming soon"))
                    }
                } else {
                    Text("Plese select an item from the sidebar")
                }
            }
            if selectedItem == .recipes {
                ShoppingOverlayView()
                    .allowsHitTesting(true)
            }
            
        }
    }
}

#Preview {
    ContentView()
}
