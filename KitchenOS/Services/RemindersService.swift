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
        // 1) Try to find an existing calendar with the given name
        let calendars = store.calendars(for: .reminder)
        if let existing = calendars.first(where: { $0.title.caseInsensitiveCompare(name) == .orderedSame }) {
            return existing
        }

        // 2) Need to create a new one. Pick a suitable source.
        let preferredSource = store.sources.first(where: { $0.sourceType == .calDAV && $0.title.contains("iCloud") })
            ?? store.sources.first(where: { $0.sourceType == .local })

        guard let source = preferredSource else {
            throw NSError(domain: "RemindersService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No suitable source found for creating a reminders list."])
        }

        let newCalendar = EKCalendar(for: .reminder, eventStore: store)
        newCalendar.title = name
        newCalendar.source = source

        try store.saveCalendar(newCalendar, commit: true)
        return newCalendar
    }
}
