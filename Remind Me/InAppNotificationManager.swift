//
//  InAppNotificationManager.swift
//  Remind Me
//
//  Created by Oliver Luu on 9/25/25.
//

import SwiftUI
import SwiftData
import Combine

@MainActor
class InAppNotificationManager: ObservableObject {
    @Published var activeNotifications: [Item] = []
    @Published var showingNotification = false
    
    private var timer: Timer?
    private var modelContext: ModelContext?
    private var shownNotificationIDs: Set<String> = [] // Track already shown notifications
    
    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
        startMonitoring()
    }
    
    private func startMonitoring() {
        // Check for due reminders every 5 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkForDueReminders()
                self?.cleanupOldShownIDs()
            }
        }
        
        // Initial check
        Task {
            await checkForDueReminders()
        }
    }
    
    private func checkForDueReminders() async {
        guard let modelContext = modelContext else { return }
        
        let now = Date()
        let fiveMinutesAgo = now.addingTimeInterval(-5 * 60) // 5 minutes ago
        
        do {
            let descriptor = FetchDescriptor<Item>(
                predicate: #Predicate<Item> { item in
                    !item.isCompleted && 
                    item.timestamp >= fiveMinutesAgo && 
                    item.timestamp <= now
                },
                sortBy: [SortDescriptor(\.timestamp, order: .forward)]
            )
            
            let dueItems = try modelContext.fetch(descriptor)
            let newNotifications = dueItems.filter { item in
                // Only show if it's not already in active notifications AND hasn't been shown before
                !activeNotifications.contains { $0.id == item.id } && 
                !shownNotificationIDs.contains(item.id)
            }
            
            if !newNotifications.isEmpty {
                print("DEBUG: Found \(newNotifications.count) new due reminders")
                // Mark these notifications as shown
                for item in newNotifications {
                    print("DEBUG: Marking '\(item.title)' (ID: \(item.id)) as shown")
                    shownNotificationIDs.insert(item.id)
                }
                
                activeNotifications.append(contentsOf: newNotifications)
                showingNotification = true
            }
            
        } catch {
            print("Error fetching due reminders: \(error)")
        }
    }
    
    func completeReminder(_ item: Item) {
        guard let modelContext = modelContext else { return }
        
        withAnimation {
            item.isCompleted = true
            removeFromActiveNotifications(item)
            
            // Create next occurrence if it's repeating
            if item.repeatFrequency != .none {
                addNextOccurrence(for: item, modelContext: modelContext)
            }
            
            do {
                try modelContext.save()
            } catch {
                print("Error saving completed reminder: \(error)")
            }
        }
    }
    
    func snoozeReminder(_ item: Item, minutes: Int = 10) {
        guard let modelContext = modelContext else { return }
        
        withAnimation {
            let snoozeDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
            let snoozeReminder = Item(
                timestamp: snoozeDate,
                title: item.title + " (Snoozed)",
                repeatFrequency: .none
            )
            
            modelContext.insert(snoozeReminder)
            removeFromActiveNotifications(item)
            
            // Schedule system notification for snoozed reminder
            Task {
                await NotificationManager.shared.scheduleNotification(for: snoozeReminder)
            }
            
            do {
                try modelContext.save()
            } catch {
                print("Error saving snoozed reminder: \(error)")
            }
        }
    }
    
    func dismissNotification(_ item: Item) {
        withAnimation {
            removeFromActiveNotifications(item)
            // Keep it in shownNotificationIDs so it doesn't appear again
        }
    }
    
    func dismissAllNotifications() {
        withAnimation {
            activeNotifications.removeAll()
            showingNotification = false
            // Keep all IDs in shownNotificationIDs so they don't appear again
        }
    }
    
    private func removeFromActiveNotifications(_ item: Item) {
        activeNotifications.removeAll { $0.id == item.id }
        if activeNotifications.isEmpty {
            showingNotification = false
        }
        // Note: We keep the item.id in shownNotificationIDs to prevent re-showing
    }
    
    
    private func cleanupOldShownIDs() {
        guard let modelContext = modelContext else { return }
        
        // Remove IDs for completed or very old reminders to prevent memory buildup
        do {
            let descriptor = FetchDescriptor<Item>()
            let allItems = try modelContext.fetch(descriptor)
            let oneDayAgo = Date().addingTimeInterval(-24 * 60 * 60)
            
            // Keep only IDs that either:
            // 1. Still exist in the database AND are not completed
            // 2. Are for reminders that are less than 24 hours old
            shownNotificationIDs = shownNotificationIDs.filter { id in
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
    
    /// Safely add a notification, checking both active notifications and shown IDs
    func addNotificationSafely(_ item: Item) {
        print("DEBUG: Attempting to add notification for '\(item.title)' (ID: \(item.id))")
        print("DEBUG: Already active: \(activeNotifications.contains(where: { $0.id == item.id }))")
        print("DEBUG: Already shown: \(shownNotificationIDs.contains(item.id))")
        
        // Only add if not already active AND not already shown
        if !activeNotifications.contains(where: { $0.id == item.id }) && 
           !shownNotificationIDs.contains(item.id) {
            print("DEBUG: Adding notification for '\(item.title)'")
            shownNotificationIDs.insert(item.id)
            activeNotifications.append(item)
            showingNotification = true
        } else {
            print("DEBUG: Skipping duplicate notification for '\(item.title)'")
        }
    }
    
    deinit {
        timer?.invalidate()
    }
}
