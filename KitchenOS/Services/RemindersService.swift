//
//  RemindersService.swift
//  KitchenOS
//
//  Created by Daniel Gergely on 3/2/26.
//
import Combine
import SwiftUI
import Foundation
import EventKit

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
    
    func exportToReminders(items: [ShoppingItem]) async {
        let granted = await requestAccess()
        guard granted else { return }

        let listName = UserDefaults.standard.string(forKey: "remindersListName") ?? "KitchenOS"

        do {
            let targetList = try findOrCreateRemindersCalendar(named: listName)

            for item in items {
                let reminder = EKReminder(eventStore: store)
                let amountPrefix = item.amount > 0 ? "\(item.amount) " : ""
                let unitPart = item.amount > 0 ? "\(item.unit.rawValue) " : ""
                reminder.title = "\(amountPrefix)\(unitPart)\(item.name)"
                reminder.calendar = targetList

                try store.save(reminder, commit: false)
            }

            try store.commit()
            HapticManager.notification(type: .success)
        } catch {
            print("Failed to find/create reminders list: \(error.localizedDescription)")
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
}
