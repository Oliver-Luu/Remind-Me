//
//  NotificationManager.swift
//  Remind Me
//
//  Created by Oliver Luu on 9/25/25.
//

import Foundation
import UserNotifications
import SwiftData
import Combine

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    // Track reminders that have persistent notifications active
    private var activePeristentReminders: Set<String> = []
    
    private init() {
        Task {
            await checkAuthorizationStatus()
        }
    }
    
    /// Request permission to send notifications
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            await checkAuthorizationStatus()
            return granted
        } catch {
            print("Error requesting notification permission: \(error)")
            return false
        }
    }
    
    /// Check current authorization status
    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }
    
    /// Schedule a notification for a reminder with persistent follow-ups
    func scheduleNotification(for item: Item) async {
        // Proceed if not denied; allow authorized, provisional, and ephemeral statuses
        guard authorizationStatus != .denied else {
            print("Notifications denied by user")
            return
        }
        
        // Handle near-past timestamps with a small grace window to avoid missing the intended minute
        let now = Date()
        if item.timestamp <= now {
            let delta = now.timeIntervalSince(item.timestamp)
            if delta <= 59 {
                // Deliver the initial notification immediately (or as soon as possible)
                await scheduleImmediateInitialNotification(for: item)
            } else {
                print("Skipping notification for past reminder: \(item.title)")
                return
            }
        } else {
            // Schedule the initial notification at the exact second
            await scheduleInitialNotification(for: item)
        }
        
        // Schedule persistent follow-up notifications
        await schedulePersistentNotifications(for: item)
    }
    
    private func scheduleInitialNotification(for item: Item) async {
        let content = createNotificationContent(for: item, isPersistent: false)
        
        // Use a precise time-interval trigger to avoid calendar rounding issues
        let interval = max(1, item.timestamp.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        
        // Create request with unique identifier
        let identifier = "reminder_\(item.id)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("Scheduled initial notification for: \(item.title) at \(item.timestamp)")
        } catch {
            print("Error scheduling initial notification: \(error)")
        }
    }

    private func scheduleImmediateInitialNotification(for item: Item) async {
        let content = createNotificationContent(for: item, isPersistent: false)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let identifier = "reminder_\(item.id)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("Scheduled immediate initial notification for: \(item.title) (grace window)")
        } catch {
            print("Error scheduling immediate initial notification: \(error)")
        }
    }
    
    private func schedulePersistentNotifications(for item: Item) async {
        guard !item.isCompleted else {
            print("Skipping persistent notifications for completed reminder: \(item.title)")
            return
        }
        guard item.notificationRepeatCount > 0 else {
            print("No persistent follow-ups configured for: \(item.title)")
            return
        }

        activePeristentReminders.insert(item.id)

        for i in 1...item.notificationRepeatCount {
            let intervalSeconds = TimeInterval(item.notificationIntervalMinutes * 60 * i)
            let followUpDate = item.timestamp.addingTimeInterval(intervalSeconds)
            guard followUpDate > Date() else { continue }

            let content = createNotificationContent(for: item, isPersistent: true, followUpNumber: i)
            let interval = followUpDate.timeIntervalSinceNow
            guard interval > 1 else { continue }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let identifier = "reminder_\(item.id)_followup_\(i)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                print("Error scheduling persistent notification \(i): \(error)")
            }
        }

        print("Scheduled \(item.notificationRepeatCount) persistent notifications for: \(item.title)")
    }
    
    private func createNotificationContent(for item: Item, isPersistent: Bool, followUpNumber: Int = 0) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        
        if isPersistent {
            content.title = "Reminder (Follow-up #\(followUpNumber))"
            content.body = "\(item.title)\n\nThis is follow-up reminder #\(followUpNumber). Please respond to stop further notifications."
        } else {
            content.title = "Reminder"
            content.body = item.title
        }
        
        // Read push sound preference from UserDefaults
        let pushKey = UserDefaults.standard.string(forKey: "settings.pushSound") ?? "default"
        switch pushKey {
        case "none":
            content.sound = nil
        case "bundled":
            if Bundle.main.url(forResource: "reminder", withExtension: "caf") != nil {
                content.sound = UNNotificationSound(named: UNNotificationSoundName("reminder.caf"))
            } else if Bundle.main.url(forResource: "reminder", withExtension: "wav") != nil {
                content.sound = UNNotificationSound(named: UNNotificationSoundName("reminder.wav"))
            } else if Bundle.main.url(forResource: "reminder", withExtension: "mp3") != nil {
                content.sound = UNNotificationSound(named: UNNotificationSoundName("reminder.mp3"))
            } else {
                content.sound = .default
            }
        default:
            content.sound = .default
        }
        
        content.badge = 1
        
        // Add custom data to identify the reminder
        content.userInfo = [
            "reminderID": item.id,
            "title": item.title,
            "isRepeating": item.repeatFrequency != .none,
            "isPersistent": isPersistent,
            "followUpNumber": followUpNumber
        ]
        
        // Add action buttons
        let completeAction = UNNotificationAction(
            identifier: "COMPLETE_ACTION",
            title: "Mark Complete",
            options: [.foreground]
        )
        
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_ACTION",
            title: "Snooze 10 min",
            options: []
        )
        
        let category = UNNotificationCategory(
            identifier: "REMINDER_CATEGORY",
            actions: [completeAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
        content.categoryIdentifier = "REMINDER_CATEGORY"
        
        return content
    }
    
    /// Cancel a scheduled notification and all its persistent follow-ups
    func cancelNotification(for item: Item) async {
        await cancelAllNotificationsForReminder(reminderID: item.id)
        print("Cancelled all notifications for: \(item.title)")
    }
    
    /// Cancel persistent notifications for a specific reminder
    func cancelPersistentNotifications(for reminderID: String) {
        Task {
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
            let ids = pending.map { $0.identifier }.filter { $0.hasPrefix("reminder_\(reminderID)_followup_") }
            center.removePendingNotificationRequests(withIdentifiers: ids)
            activePeristentReminders.remove(reminderID)
            print("Cancelled persistent notifications for reminder: \(reminderID)")
        }
    }
    
    /// Cancel all notifications (main + persistent) for a specific reminder
    private func cancelAllNotificationsForReminder(reminderID: String) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let pendingIDs = pending.map { $0.identifier }.filter { id in
            id == "reminder_\(reminderID)" || id.hasPrefix("reminder_\(reminderID)_followup_")
        }
        center.removePendingNotificationRequests(withIdentifiers: pendingIDs)

        let delivered = await center.deliveredNotifications()
        let deliveredIDs = delivered.map { $0.request.identifier }.filter { id in
            id == "reminder_\(reminderID)" || id.hasPrefix("reminder_\(reminderID)_followup_")
        }
        center.removeDeliveredNotifications(withIdentifiers: deliveredIDs)

        activePeristentReminders.remove(reminderID)
        print("Cancelled all notifications (pending and delivered) for reminder: \(reminderID)")
    }
    
    /// Schedule notifications for multiple reminders
    func scheduleNotifications(for items: [Item]) async {
        for item in items {
            await scheduleNotification(for: item)
        }
    }
    
    /// Schedule a one-off test notification for Settings
    func scheduleTestNotification() async {
        // Proceed if not denied; allow authorized, provisional, and ephemeral statuses
        guard authorizationStatus != .denied else {
            print("Notifications denied by user")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "This is a test notification from Settings."

        // Read push sound preference from UserDefaults (same as normal notifications)
        let pushKey = UserDefaults.standard.string(forKey: "settings.pushSound") ?? "default"
        switch pushKey {
        case "none":
            content.sound = nil
        case "bundled":
            if Bundle.main.url(forResource: "reminder", withExtension: "caf") != nil {
                content.sound = UNNotificationSound(named: UNNotificationSoundName("reminder.caf"))
            } else if Bundle.main.url(forResource: "reminder", withExtension: "wav") != nil {
                content.sound = UNNotificationSound(named: UNNotificationSoundName("reminder.wav"))
            } else if Bundle.main.url(forResource: "reminder", withExtension: "mp3") != nil {
                content.sound = UNNotificationSound(named: UNNotificationSoundName("reminder.mp3"))
            } else {
                content.sound = .default
            }
        default:
            content.sound = .default
        }
        // Mark as a test so we can present banners/sounds in the foreground
        content.userInfo["isTest"] = true

        // Deliver immediately (no trigger)
        let identifier = "test_notification_\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("Scheduled test notification")
        } catch {
            print("Error scheduling test notification: \(error)")
        }
    }
    
    /// Cancel notifications for multiple reminders
    func cancelNotifications(for items: [Item]) async {
        for item in items {
            await cancelAllNotificationsForReminder(reminderID: item.id)
        }
    }
    
    /// Handle notification actions
    func handleNotificationAction(_ actionIdentifier: String, for notification: UNNotification, modelContext: ModelContext) async {
        let userInfo = notification.request.content.userInfo
        
        guard let reminderID = userInfo["reminderID"] as? String else {
            print("Could not find reminder ID in notification")
            return
        }
        
        switch actionIdentifier {
        case "COMPLETE_ACTION":
            // First cancel all notifications for this reminder
            await cancelAllNotificationsForReminder(reminderID: reminderID)
            await markReminderComplete(reminderID: reminderID, modelContext: modelContext)
        case "SNOOZE_ACTION":
            // Cancel all notifications for this reminder before snoozing
            await cancelAllNotificationsForReminder(reminderID: reminderID)
            await snoozeReminder(reminderID: reminderID, modelContext: modelContext)
        case UNNotificationDismissActionIdentifier:
            // User dismissed the notification - don't stop persistent notifications
            // They will continue to receive follow-ups
            break
        default:
            break
        }
    }
    
    private func markReminderComplete(reminderID: String, modelContext: ModelContext) async {
        let descriptor = FetchDescriptor<Item>()
        do {
            let items = try modelContext.fetch(descriptor)
            if let item = items.first(where: { $0.id == reminderID }) {
                item.isCompleted = true
                try modelContext.save()
                
                // Make sure to cancel any remaining notifications for this item
                await cancelAllNotificationsForReminder(reminderID: reminderID)
                
                print("Marked reminder complete and cancelled all notifications: \(item.title)")
            }
        } catch {
            print("Error marking reminder complete: \(error)")
        }
    }
    
    private func snoozeReminder(reminderID: String, modelContext: ModelContext) async {
        let descriptor = FetchDescriptor<Item>()
        do {
            let items = try modelContext.fetch(descriptor)
            if let item = items.first(where: { $0.id == reminderID }) {
                // Create a new reminder at the snooze time
                let snoozeDate = Date().addingTimeInterval(10 * 60) // 10 minutes
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
                modelContext.insert(snoozeReminder)
                
                // Delete the original reminder since it has been snoozed
                modelContext.delete(item)
                
                try modelContext.save()
                
                // Schedule notification for the snoozed reminder
                await scheduleNotification(for: snoozeReminder)
                print("Snoozed reminder (keeping series membership if applicable) and deleted original: \(snoozeReminder.title)")
            }
        } catch {
            print("Error snoozing reminder: \(error)")
        }
    }
    
    /// Check if a reminder has active persistent notifications
    func hasPersistentNotifications(for reminderID: String) -> Bool {
        return activePeristentReminders.contains(reminderID)
    }
    
    /// Get the count of reminders with active persistent notifications
    var activePersistentCount: Int {
        return activePeristentReminders.count
    }
    
    /// Stop all persistent notifications (emergency stop)
    func stopAllPersistentNotifications() {
        Task {
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
            var identifiersToCancel: [String] = []

            for reminderID in activePeristentReminders {
                let ids = pending.map { $0.identifier }.filter { $0.hasPrefix("reminder_\(reminderID)_followup_") }
                identifiersToCancel.append(contentsOf: ids)
            }

            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToCancel)
            activePeristentReminders.removeAll()

            print("Stopped all persistent notifications")
        }
    }
    
    /// Call this method when a reminder is marked as completed from the UI
    func handleReminderCompleted(_ item: Item) async {
        await cancelAllNotificationsForReminder(reminderID: item.id)
    }
    
    /// Call this method when a reminder is deleted from the UI
    func handleReminderDeleted(_ item: Item) async {
        await cancelAllNotificationsForReminder(reminderID: item.id)
    }
}

