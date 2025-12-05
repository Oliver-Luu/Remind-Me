//
//  RepeatingReminderManager.swift
//  Remind Me
//
//  Created by Oliver Luu on 9/24/25.
//

import Foundation
import SwiftData

/// Creates repeating reminders based on the specified frequency and parameters
@MainActor
@discardableResult
func addRepeatingReminders(
    title: String,
    startDate: Date,
    repeatFrequency: RepeatFrequency,
    repeatInterval: Int,
    numberOfOccurrences: Int,
    modelContext: ModelContext,
    notificationIntervalMinutes: Int,
    notificationRepeatCount: Int
) -> Item {
    // Create a unique ID for this set of repeating reminders
    let parentID = UUID().uuidString
    var remindersToSchedule: [Item] = []
    
    let start = floorToMinute(startDate)
    
    // Always create the initial reminder
    let initialReminder = Item(
        timestamp: start,
        title: title,
        repeatFrequency: repeatFrequency,
        parentReminderID: repeatFrequency == .none ? nil : parentID,
        notificationIntervalMinutes: notificationIntervalMinutes,
        notificationRepeatCount: notificationRepeatCount,
        repeatInterval: repeatInterval
    )
    modelContext.insert(initialReminder)
    remindersToSchedule.append(initialReminder)
    
    // Persist immediately so other contexts (e.g., in-app notifier) can see it
    try? modelContext.save()
    
    // If it's not repeating, we're done
    if repeatFrequency == .none {
        Task { @MainActor in
            await NotificationManager.shared.scheduleNotifications(for: remindersToSchedule)
        }
        return initialReminder
    }
    
    // Create additional reminders based on the repeat frequency
    let calendar = Calendar.current
    var currentDate = start
    
    for _ in 0..<numberOfOccurrences {
        currentDate = nextOccurrenceDate(from: currentDate, frequency: repeatFrequency, interval: repeatInterval, calendar: calendar)
        
        let reminder = Item(
            timestamp: currentDate,
            title: title,
            repeatFrequency: repeatFrequency,
            parentReminderID: parentID,
            notificationIntervalMinutes: notificationIntervalMinutes,
            notificationRepeatCount: notificationRepeatCount,
            repeatInterval: repeatInterval
        )
        modelContext.insert(reminder)
        remindersToSchedule.append(reminder)
    }
    
    // Persist all newly created reminders before scheduling
    try? modelContext.save()
    
    // Schedule notifications for all reminders
    Task { @MainActor in
        await NotificationManager.shared.scheduleNotifications(for: remindersToSchedule)
    }
    
    return initialReminder
}

/// Calculates the next occurrence date based on the repeat frequency
private func nextOccurrenceDate(from date: Date, frequency: RepeatFrequency, interval: Int, calendar: Calendar) -> Date {
    switch frequency {
    case .none:
        return date
    case .daily:
        return calendar.date(byAdding: .day, value: interval, to: date) ?? date
    case .weekly:
        return calendar.date(byAdding: .weekOfYear, value: interval, to: date) ?? date
    case .monthly:
        return calendar.date(byAdding: .month, value: interval, to: date) ?? date
    case .yearly:
        return calendar.date(byAdding: .year, value: interval, to: date) ?? date
    case .custom:
        return date
    }
}

/// Creates a single additional occurrence for an existing repeating reminder
func addNextOccurrence(for item: Item, modelContext: ModelContext) {
    guard item.repeatFrequency != .none && item.repeatFrequency != .custom else { return }
    
    let calendar = Calendar.current
    let nextDate = nextOccurrenceDate(from: item.timestamp, frequency: item.repeatFrequency, interval: max(1, item.repeatInterval), calendar: calendar)
    
    // Prevent duplicates: if there’s already an item at nextDate in the same series, do nothing
    if let parentID = item.parentReminderID {
        let descriptor = FetchDescriptor<Item>(
            predicate: #Predicate<Item> { it in
                it.parentReminderID == parentID && it.timestamp == nextDate
            }
        )
        if let existing = try? modelContext.fetch(descriptor), !existing.isEmpty {
            return
        }
    }
    
    let nextReminder = Item(
        timestamp: nextDate,
        title: item.title,
        repeatFrequency: item.repeatFrequency,
        parentReminderID: item.parentReminderID,
        notificationIntervalMinutes: item.notificationIntervalMinutes,
        notificationRepeatCount: item.notificationRepeatCount,
        repeatInterval: item.repeatInterval
    )
    modelContext.insert(nextReminder)
    
    // Schedule notification for the new reminder
    Task { @MainActor in
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

