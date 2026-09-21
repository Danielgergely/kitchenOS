//
//  RemindersService.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/2/26.
//
import Combine
import SwiftUI
import Foundation
internal import EventKit

@MainActor
class RemindersService: ObservableObject {
    static let shared = RemindersService()
    private let store = EKEventStore()
    
    func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToReminders()
        } catch {
            print("Access denied: \(error.localizedDescription)")
            return false
        }
    }
    
    enum ExportResult: Equatable {
        case success(count: Int, listName: String)
        case empty
        case accessDenied
        case failure(String)

        /// Alert copy lives with the result so every screen that exports says the same thing.
        var alertTitle: String {
            switch self {
            case .success:      return "Exported"
            case .empty:        return "Nothing to Export"
            case .accessDenied: return "Reminders Access Needed"
            case .failure:      return "Export Failed"
            }
        }

        var alertMessage: String {
            switch self {
            case .success(let count, let listName):
                return "Added \(count) item\(count == 1 ? "" : "s") to your \"\(listName)\" list in Reminders."
            case .empty:
                return "Your shopping list is empty."
            case .accessDenied:
                return "Allow access to Reminders in Settings to export your shopping list."
            case .failure(let message):
                return message
            }
        }
    }

    @discardableResult
    func exportToReminders(items: [ShoppingItem]) async -> ExportResult {
        guard !items.isEmpty else { return .empty }

        let granted = await requestAccess()
        guard granted else {
            HapticManager.notification(type: .error)
            return .accessDenied
        }

        let listName = UserDefaults.standard.string(forKey: "remindersListName") ?? "MealOS"

        do {
            let targetList = try findOrCreateRemindersCalendar(named: listName)

            for item in items {
                let reminder = EKReminder(eventStore: store)
                let amountPrefix = item.amount > 0 ? "\(item.amount) " : ""
                let unitPart = item.amount > 0 ? "\(item.unit.rawValue) " : ""
                reminder.title = "\(amountPrefix)\(unitPart)\(item.name)"
                reminder.calendar = targetList

                try store.save(reminder, commit: false)

                item.reminderId = reminder.calendarItemIdentifier
            }

            try store.commit()
            HapticManager.notification(type: .success)
            return .success(count: items.count, listName: listName)
        } catch {
            print("Failed to find/create reminders list: \(error.localizedDescription)")
            HapticManager.notification(type: .error)
            return .failure(error.localizedDescription)
        }
    }
    
    private func findOrCreateRemindersCalendar(named name: String) throws -> EKCalendar {
        let calendars = store.calendars(for: .reminder)
        
        // 1) Clean up the search string (removes trailing spaces and makes it lowercase)
        let searchName = name.trimmingCharacters(in: .whitespaces).lowercased()
        
        // 2) Try to find an existing calendar with the given name
        if let existing = calendars.first(where: {
            $0.title.trimmingCharacters(in: .whitespaces).lowercased() == searchName
        }) {
            print("✅ Found existing list: \(existing.title)")
            return existing
        }

        // 3) Need to create a new one. Pick a suitable source.
        print("⚠️ List not found. Creating new list: \(name)")
        let newCalendar = EKCalendar(for: .reminder, eventStore: store)
        newCalendar.title = name
        
        if let defaultSource = store.defaultCalendarForNewReminders()?.source {
            newCalendar.source = defaultSource
        } else if let calDAVSource = store.sources.first(where: { $0.sourceType == .calDAV }) {
            newCalendar.source = calDAVSource
        } else if let localSource = store.sources.first(where: { $0.sourceType == .local }) {
            newCalendar.source = localSource
        } else {
            throw NSError(domain: "RemindersService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No suitable source found for creating a reminders list."])
        }

        try store.saveCalendar(newCalendar, commit: true)
        return newCalendar
    }
    
    func syncItemsWithReminders(items: [ShoppingItem]) {
        // Only check items that actually have a linked reminder ID and aren't checked yet
        let linkedItems = items.filter { $0.reminderId != nil && !$0.isChecked }
        
        for item in linkedItems {
            // Look up the exact reminder using the secret ID
            if let reminderId = item.reminderId,
               let reminder = store.calendarItem(withIdentifier: reminderId) as? EKReminder {
                
                // If it is checked off in Apple Reminders, check it off in KitchenOS!
                if reminder.isCompleted {
                    item.isChecked = true
                }
            }
        }
    }
}
