//
//  RepeatingReminderManager.swift
//  Remind Me
//
//  Created by Oliver Luu on 9/24/25.
//

import Foundation
import SwiftData

/// Creates repeating reminders based on the specified frequency and parameters
func addRepeatingReminders(
    title: String,
    startDate: Date,
    repeatFrequency: RepeatFrequency,
    numberOfOccurrences: Int,
    modelContext: ModelContext,
    notificationIntervalMinutes: Int,
    notificationRepeatCount: Int
) {
    // Create a unique ID for this set of repeating reminders
    let parentID = UUID().uuidString
    var remindersToSchedule: [Item] = []
    
    // Always create the initial reminder
    let initialReminder = Item(
        timestamp: startDate,
        title: title,
        repeatFrequency: repeatFrequency,
        parentReminderID: repeatFrequency == .none ? nil : parentID,
        notificationIntervalMinutes: notificationIntervalMinutes,
        notificationRepeatCount: notificationRepeatCount
    )
    modelContext.insert(initialReminder)
    remindersToSchedule.append(initialReminder)
    
    // If it's not repeating, we're done
    guard repeatFrequency != .none else { 
        Task {
            await NotificationManager.shared.scheduleNotifications(for: remindersToSchedule)
        }
        return 
    }
    
    // Create additional reminders based on the repeat frequency
    let calendar = Calendar.current
    var currentDate = startDate
    
    for _ in 1..<numberOfOccurrences {
        currentDate = nextOccurrenceDate(from: currentDate, frequency: repeatFrequency, calendar: calendar)
        
        let reminder = Item(
            timestamp: currentDate,
            title: title,
            repeatFrequency: repeatFrequency,
            parentReminderID: parentID,
            notificationIntervalMinutes: notificationIntervalMinutes,
            notificationRepeatCount: notificationRepeatCount
        )
        modelContext.insert(reminder)
        remindersToSchedule.append(reminder)
    }
    
    // Schedule notifications for all reminders
    Task {
        await NotificationManager.shared.scheduleNotifications(for: remindersToSchedule)
    }
}

/// Calculates the next occurrence date based on the repeat frequency
private func nextOccurrenceDate(from date: Date, frequency: RepeatFrequency, calendar: Calendar) -> Date {
    switch frequency {
    case .none:
        return date
    case .daily:
        return calendar.date(byAdding: .day, value: 1, to: date) ?? date
    case .weekly:
        return calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
    case .monthly:
        return calendar.date(byAdding: .month, value: 1, to: date) ?? date
    case .yearly:
        return calendar.date(byAdding: .year, value: 1, to: date) ?? date
    }
}

/// Creates a single additional occurrence for an existing repeating reminder
func addNextOccurrence(for item: Item, modelContext: ModelContext) {
    guard item.repeatFrequency != .none else { return }
    
    let calendar = Calendar.current
    let nextDate = nextOccurrenceDate(from: item.timestamp, frequency: item.repeatFrequency, calendar: calendar)
    
    let nextReminder = Item(
        timestamp: nextDate,
        title: item.title,
        repeatFrequency: item.repeatFrequency,
        parentReminderID: item.parentReminderID
    )
    modelContext.insert(nextReminder)
    
    // Schedule notification for the new reminder
    Task {
        await NotificationManager.shared.scheduleNotification(for: nextReminder)
    }
}

/// Removes all future occurrences of a repeating reminder series
func removeAllFutureOccurrences(for item: Item, modelContext: ModelContext) async {
    guard let parentID = item.parentReminderID else { return }
    
    // Find all reminders in the same series that occur after the current one
    let allItemsDescriptor = FetchDescriptor<Item>(
        sortBy: [SortDescriptor(\.timestamp)]
    )
    
    do {
        let allItems = try modelContext.fetch(allItemsDescriptor)
        let futureReminders = allItems.filter { reminder in
            reminder.parentReminderID == parentID && reminder.timestamp > item.timestamp
        }
        
        // Cancel notifications for future reminders
        await NotificationManager.shared.cancelNotifications(for: futureReminders)
        
        for reminder in futureReminders {
            modelContext.delete(reminder)
        }
    } catch {
        print("Error removing future occurrences: \(error)")
    }
}

/// Gets all reminders in the same repeating series
func getRelatedReminders(for item: Item, modelContext: ModelContext) -> [Item] {
    guard let parentID = item.parentReminderID else { return [item] }
    
    let allItemsDescriptor = FetchDescriptor<Item>(
        sortBy: [SortDescriptor(\.timestamp)]
    )
    
    do {
        let allItems = try modelContext.fetch(allItemsDescriptor)
        return allItems.filter { reminder in
            reminder.parentReminderID == parentID
        }
    } catch {
        print("Error fetching related reminders: \(error)")
        return [item]
    }
}
