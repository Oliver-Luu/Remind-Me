//
//  InAppNotificationManager.swift
//  Remind Me
//
//  Created by Oliver Luu on 9/25/25.
//

import SwiftUI
import SwiftData
import Combine
import UIKit

@MainActor
class InAppNotificationManager: ObservableObject {
    @Published var activeNotifications: [Item] = []
    @Published var showingNotification = false
    
    // Timers to fire in-app banners exactly at due time
    private var scheduledTimers: [String: Timer] = [:]
    
    private var modelContext: ModelContext?
    // Track when a reminder was last shown in-app
    private var lastShownAt: [String: Date] = [:]
    
    private func playInAppReminderSound() {
        NotificationSoundPlayer.shared.playReminderSound()
    }
    
    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
        // Schedule triggers for all upcoming reminders
        Task { @MainActor in
            self.scheduleAllUpcomingInAppTriggers()
            self.catchUpPastDueReminders()
        }
        // Observe app becoming active to reschedule any missed timers
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    @objc private func handleAppDidBecomeActive(_ notification: Notification) {
        // Reschedule any missed timers when app becomes active
        scheduleAllUpcomingInAppTriggers()
        catchUpPastDueReminders()
    }
    
    /// Schedule an exact in-app trigger for this reminder's due time
    func scheduleInAppTrigger(for item: Item) {
        // Don't schedule for completed items
        guard !item.isCompleted else { return }
        // Cancel any existing timer for this item
        cancelInAppTrigger(for: item)
        let fireDate = item.timestamp
        let interval = fireDate.timeIntervalSinceNow
        if interval <= 0 {
            // If already due or slightly past, show immediately
            addNotificationSafely(item)
            return
        }
        let info: [String: Any] = ["id": item.id]
        let timer = Timer(fireAt: fireDate, interval: 0, target: self, selector: #selector(inAppTriggerFired(_:)), userInfo: info, repeats: false)
        RunLoop.main.add(timer, forMode: .common)
        scheduledTimers[item.id] = timer
    }

    /// Cancel any scheduled in-app trigger for this reminder
    func cancelInAppTrigger(for item: Item) {
        if let t = scheduledTimers[item.id] {
            t.invalidate()
            scheduledTimers.removeValue(forKey: item.id)
        }
    }
    
    @objc private func inAppTriggerFired(_ timer: Timer) {
        defer { timer.invalidate() }
        var itemID: String? = nil
        if let info = timer.userInfo as? [String: Any] {
            itemID = info["id"] as? String
        } else if let id = timer.userInfo as? String {
            itemID = id
        }
        if let id = itemID {
            scheduledTimers.removeValue(forKey: id)
        }
        guard let id = itemID, let item = fetchItem(withID: id), !item.isCompleted else {
            return
        }
        addNotificationSafely(item)
    }

    private func fetchItem(withID id: String) -> Item? {
        guard let modelContext = modelContext else { return nil }
        do {
            let descriptor = FetchDescriptor<Item>(
                predicate: #Predicate<Item> { it in it.id == id }
            )
            return try modelContext.fetch(descriptor).first
        } catch {
            print("Error fetching item by id \(id): \(error)")
            return nil
        }
    }
    
    private func catchUpPastDueReminders() {
        guard let modelContext = modelContext else { return }
        let now = Date()
        let tenMinutesAgo = now.addingTimeInterval(-10 * 60)
        do {
            let descriptor = FetchDescriptor<Item>(
                predicate: #Predicate<Item> { item in
                    !item.isCompleted && item.timestamp >= tenMinutesAgo && item.timestamp <= now
                },
                sortBy: [SortDescriptor(\.timestamp, order: .forward)]
            )
            let dueItems = try modelContext.fetch(descriptor)
            for item in dueItems {
                addNotificationSafely(item)
            }
            // Periodically clean up old shown IDs
            cleanupOldShownIDs()
        } catch {
            print("Error fetching past-due reminders: \(error)")
        }
    }
    
    func completeReminder(_ item: Item) {
        guard let modelContext = modelContext else { return }
        
        withAnimation {
            item.isCompleted = true
            cancelInAppTrigger(for: item)
            removeFromActiveNotifications(item)
            
            print("DEBUG: Marking reminder '\(item.title)' as completed (ID: \(item.id))")
            
            // Cancel all notifications for this reminder
            Task {
                await NotificationManager.shared.handleReminderCompleted(item)
            }
            
            // Maintain a rolling window of future items if this is a repeating series
            if item.repeatFrequency != .none {
                if let parentID = item.parentReminderID {
                    // Add after the last item in the series to avoid duplicating an already-created “next”
                    do {
                        let descriptor = FetchDescriptor<Item>(
                            predicate: #Predicate<Item> { it in it.parentReminderID == parentID },
                            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
                        )
                        if let seriesLast = try modelContext.fetch(descriptor).last {
                            addNextOccurrence(for: seriesLast, modelContext: modelContext)
                        }
                    } catch {
                        // If we can't load the series, fall back to adding after the completed item
                        addNextOccurrence(for: item, modelContext: modelContext)
                    }
                } else {
                    // No parent series recorded — generate next based on this item
                    addNextOccurrence(for: item, modelContext: modelContext)
                }
            }
            
            do {
                try modelContext.save()
                print("DEBUG: Successfully saved completed reminder to context")
            } catch {
                print("Error saving completed reminder: \(error)")
            }
        }
    }
    
    func snoozeReminder(_ item: Item, minutes: Int = 10) {
        guard let modelContext = modelContext else { return }

        withAnimation {
            // Cancel notifications for the original reminder
            Task {
                await NotificationManager.shared.handleReminderCompleted(item)
            }
            
            let snoozeDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
            let isRepeating = (item.parentReminderID != nil)
            
            let snoozeReminder = Item(
                timestamp: snoozeDate,
                title: item.title + " (Snoozed)",
                repeatFrequency: isRepeating ? item.repeatFrequency : .none,
                parentReminderID: isRepeating ? item.parentReminderID : nil,
                notificationIntervalMinutes: item.notificationIntervalMinutes,
                notificationRepeatCount: item.notificationRepeatCount,
                repeatInterval: isRepeating ? item.repeatInterval : 1
            )
            
            // Insert the new snoozed reminder
            modelContext.insert(snoozeReminder)
            
            // Remove the original from any active UI state and cancel its in-app trigger
            removeFromActiveNotifications(item)
            cancelInAppTrigger(for: item)
            
            // Schedule in-app and system notifications for the snoozed reminder
            scheduleInAppTrigger(for: snoozeReminder)
            Task {
                await NotificationManager.shared.scheduleNotification(for: snoozeReminder)
            }
            
            // Delete the original reminder since it has been snoozed and replaced
            modelContext.delete(item)
            
            do {
                try modelContext.save()
            } catch {
                print("Error saving snoozed reminder changes: \(error)")
            }
        }
    }
    
    func dismissNotification(_ item: Item) {
        withAnimation {
            removeFromActiveNotifications(item)
            // Keep it in lastShownAt so it doesn't appear again if appropriate
        }
    }
    
    func dismissAllNotifications() {
        withAnimation {
            activeNotifications.removeAll()
            showingNotification = false
            // No changes needed for lastShownAt here
        }
    }
    
    private func removeFromActiveNotifications(_ item: Item) {
        activeNotifications.removeAll { $0.id == item.id }
        if activeNotifications.isEmpty {
            showingNotification = false
        }
        // Note: We keep the lastShownAt entries to prevent re-showing unnecessarily
    }
    
    
    private func cleanupOldShownIDs() {
        guard let modelContext = modelContext else { return }
        do {
            let descriptor = FetchDescriptor<Item>()
            let allItems = try modelContext.fetch(descriptor)
            let oneDayAgo = Date().addingTimeInterval(-24 * 60 * 60)
            // Keep entries for items that still exist and are not completed and are not too old
            lastShownAt = lastShownAt.filter { (id, _) in
                if let item = allItems.first(where: { $0.id == id }) {
                    return !item.isCompleted && item.timestamp > oneDayAgo
                }
                return false
            }
        } catch {
            print("Error cleaning up shown IDs: \(error)")
        }
    }
    
    func addNotificationForTesting(_ item: Item) {
        if !activeNotifications.contains(where: { $0.id == item.id }) {
            activeNotifications.append(item)
            showingNotification = true
        }
    }
    
    /// Safely add a notification, checking both active notifications and last shown timestamps
    func addNotificationSafely(_ item: Item) {
        print("DEBUG: Attempting to add notification for '\(item.title)' (ID: \(item.id))")
        let isActive = activeNotifications.contains(where: { $0.id == item.id })
        let last = lastShownAt[item.id]
        let now = Date()
        let allowReshowAtDue = (last == nil) || (now >= item.timestamp && (last! < item.timestamp))
        print("DEBUG: Already active: \(isActive), last shown: \(String(describing: last)), allowReshowAtDue: \(allowReshowAtDue)")
        if !isActive && allowReshowAtDue {
            lastShownAt[item.id] = now
            activeNotifications.append(item)
            playInAppReminderSound()
            showingNotification = true
        } else {
            print("DEBUG: Skipping duplicate/early notification for '\(item.title)'")
        }
    }
    
    private func scheduleAllUpcomingInAppTriggers() {
        guard let modelContext = modelContext else { return }
        do {
            let now = Date()
            let descriptor = FetchDescriptor<Item>(
                predicate: #Predicate<Item> { it in !it.isCompleted && it.timestamp > now }
            )
            let items = try modelContext.fetch(descriptor)
            for it in items {
                scheduleInAppTrigger(for: it)
            }
        } catch {
            print("Error scheduling upcoming in-app triggers: \(error)")
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
    }
}

