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
    private let maxPersistentNotifications = 10 // Limit to avoid overwhelming the user
    
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
        // Make sure we have permission
        guard authorizationStatus == .authorized else {
            print("Notifications not authorized")
            return
        }
        
        // Don't schedule notifications for past dates
        guard item.timestamp > Date() else {
            print("Skipping notification for past reminder: \(item.title)")
            return
        }
        
        // Schedule the initial notification
        await scheduleInitialNotification(for: item)
        
        // Schedule persistent follow-up notifications
        await schedulePersistentNotifications(for: item)
    }
    
    private func scheduleInitialNotification(for item: Item) async {
        let content = createNotificationContent(for: item, isPersistent: false)
        
        // Create trigger for the exact time
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: item.timestamp)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        
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
    
    private func schedulePersistentNotifications(for item: Item) async {
        // Add to active persistent reminders
        activePeristentReminders.insert(item.id)
        
        // Schedule follow-up notifications every minute for the next 10 minutes
        for i in 1...maxPersistentNotifications {
            let followUpDate = item.timestamp.addingTimeInterval(TimeInterval(i * 60)) // i minutes after original
            
            // Don't schedule if it would be in the past
            guard followUpDate > Date() else { continue }
            
            let content = createNotificationContent(for: item, isPersistent: true, followUpNumber: i)
            
            let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: followUpDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            
            let identifier = "reminder_\(item.id)_followup_\(i)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                print("Error scheduling persistent notification \(i): \(error)")
            }
        }
        
        print("Scheduled persistent notifications for: \(item.title)")
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
        
        content.sound = .default
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
        
        let stopAction = UNNotificationAction(
            identifier: "STOP_PERSISTENT_ACTION",
            title: "Stop Reminders",
            options: [.destructive]
        )
        
        let category = UNNotificationCategory(
            identifier: "REMINDER_CATEGORY",
            actions: isPersistent ? [completeAction, snoozeAction, stopAction] : [completeAction, snoozeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
        content.categoryIdentifier = "REMINDER_CATEGORY"
        
        return content
    }
    
    /// Cancel a scheduled notification and all its persistent follow-ups
    func cancelNotification(for item: Item) {
        // Cancel the main notification
        let identifier = "reminder_\(item.id)"
        var identifiersToCancel = [identifier]
        
        // Cancel all persistent follow-up notifications
        for i in 1...maxPersistentNotifications {
            identifiersToCancel.append("reminder_\(item.id)_followup_\(i)")
        }
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToCancel)
        
        // Remove from active persistent reminders
        activePeristentReminders.remove(item.id)
        
        print("Cancelled all notifications for: \(item.title)")
    }
    
    /// Cancel persistent notifications for a specific reminder
    func cancelPersistentNotifications(for reminderID: String) {
        var identifiersToCancel: [String] = []
        
        // Cancel all persistent follow-up notifications
        for i in 1...maxPersistentNotifications {
            identifiersToCancel.append("reminder_\(reminderID)_followup_\(i)")
        }
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToCancel)
        
        // Remove from active persistent reminders
        activePeristentReminders.remove(reminderID)
        
        print("Cancelled persistent notifications for reminder: \(reminderID)")
    }
    
    /// Schedule notifications for multiple reminders
    func scheduleNotifications(for items: [Item]) async {
        for item in items {
            await scheduleNotification(for: item)
        }
    }
    
    /// Cancel notifications for multiple reminders
    func cancelNotifications(for items: [Item]) {
        var allIdentifiers: [String] = []
        
        for item in items {
            // Add main notification identifier
            allIdentifiers.append("reminder_\(item.id)")
            
            // Add persistent follow-up identifiers
            for i in 1...maxPersistentNotifications {
                allIdentifiers.append("reminder_\(item.id)_followup_\(i)")
            }
            
            // Remove from active persistent reminders
            activePeristentReminders.remove(item.id)
        }
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: allIdentifiers)
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
            // Stop persistent notifications when completing
            cancelPersistentNotifications(for: reminderID)
            await markReminderComplete(reminderID: reminderID, modelContext: modelContext)
        case "SNOOZE_ACTION":
            // Stop current persistent notifications and schedule new ones for snoozed reminder
            cancelPersistentNotifications(for: reminderID)
            await snoozeReminder(reminderID: reminderID, modelContext: modelContext)
        case "STOP_PERSISTENT_ACTION":
            // Stop persistent notifications without completing the reminder
            cancelPersistentNotifications(for: reminderID)
            print("Stopped persistent notifications for reminder: \(reminderID)")
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
                print("Marked reminder complete: \(item.title)")
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
                // Create a new reminder 10 minutes from now
                let snoozeDate = Date().addingTimeInterval(10 * 60) // 10 minutes
                let snoozeReminder = Item(
                    timestamp: snoozeDate,
                    title: item.title + " (Snoozed)",
                    repeatFrequency: .none
                )
                modelContext.insert(snoozeReminder)
                try modelContext.save()
                
                // Schedule notification for snoozed reminder
                await scheduleNotification(for: snoozeReminder)
                print("Snoozed reminder: \(item.title)")
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
        var identifiersToCancel: [String] = []
        
        for reminderID in activePeristentReminders {
            for i in 1...maxPersistentNotifications {
                identifiersToCancel.append("reminder_\(reminderID)_followup_\(i)")
            }
        }
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToCancel)
        activePeristentReminders.removeAll()
        
        print("Stopped all persistent notifications")
    }
}
