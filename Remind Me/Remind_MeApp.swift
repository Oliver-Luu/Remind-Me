//
//  Remind_MeApp.swift
//  Remind Me
//
//  Created by Oliver Luu on 9/22/25.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct Remind_MeApp: App {
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var inAppNotificationManager = InAppNotificationManager()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(notificationManager)
                    .environmentObject(inAppNotificationManager)
                    .onAppear {
                        setupNotificationDelegate()
                        setupInAppNotifications()
                        Task {
                            await requestNotificationPermission()
                        }
                    }
                
                // Overlay in-app notifications on top of everything
                InAppNotificationView(inAppNotificationManager: inAppNotificationManager)
            }
        }
        .modelContainer(sharedModelContainer)
    }
    
    private func setupNotificationDelegate() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        NotificationDelegate.shared.modelContainer = sharedModelContainer
        NotificationDelegate.shared.inAppNotificationManager = inAppNotificationManager
    }
    
    private func setupInAppNotifications() {
        let modelContext = ModelContext(sharedModelContainer)
        inAppNotificationManager.setup(modelContext: modelContext)
    }
    
    private func requestNotificationPermission() async {
        _ = await notificationManager.requestNotificationPermission()
    }
}

// Notification delegate to handle notification actions
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    var modelContainer: ModelContainer?
    var inAppNotificationManager: InAppNotificationManager?
    
    private override init() {
        super.init()
    }
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("DEBUG: System notification firing while app in foreground")
        // When app is in foreground, show in-app notification instead of system banner
        Task { @MainActor in
            await triggerInAppNotification(from: notification)
        }
        
        // Still play sound and show badge
        completionHandler([.sound, .badge])
    }
    
    // Handle notification actions
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        guard let modelContainer = modelContainer else {
            completionHandler()
            return
        }
        
        Task { @MainActor in
            let modelContext = ModelContext(modelContainer)
            await NotificationManager.shared.handleNotificationAction(
                response.actionIdentifier,
                for: response.notification,
                modelContext: modelContext
            )
            
            // Also trigger in-app notification for better visibility
            await triggerInAppNotification(from: response.notification)
            
            completionHandler()
        }
    }
    
    @MainActor
    private func triggerInAppNotification(from notification: UNNotification) async {
        print("DEBUG: triggerInAppNotification called")
        guard let modelContainer = modelContainer,
              let inAppManager = inAppNotificationManager,
              let reminderID = notification.request.content.userInfo["reminderID"] as? String else {
            print("DEBUG: Missing required components for in-app notification")
            return
        }
        
        print("DEBUG: Looking for reminder with ID: \(reminderID)")
        let modelContext = ModelContext(modelContainer)
        
        do {
            let descriptor = FetchDescriptor<Item>()
            let items = try modelContext.fetch(descriptor)
            
            if let reminder = items.first(where: { $0.id == reminderID && !$0.isCompleted }) {
                print("DEBUG: Found reminder '\(reminder.title)', triggering in-app notification")
                // Use the safe method that checks for duplicates and tracks shown IDs
                inAppManager.addNotificationSafely(reminder)
            } else {
                print("DEBUG: Reminder not found or already completed")
            }
        } catch {
            print("Error triggering in-app notification: \(error)")
        }
    }
}
