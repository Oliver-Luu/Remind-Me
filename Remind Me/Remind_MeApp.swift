//
//  Remind_MeApp.swift
//  Remind Me
//
//  Created by Oliver Luu on 9/22/25.
//

import UIKit
import SwiftUI
import SwiftData
import UserNotifications

@main
struct Remind_MeApp: App {
    @AppStorage("settings.appearance") private var appearance: String = "system"
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var inAppNotificationManager = InAppNotificationManager()
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var appearanceOverlayColor: Color = .clear
    @State private var isAppearanceTransitioning: Bool = false
    @State private var pendingColorScheme: ColorScheme? = nil
    
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
            .preferredColorScheme(pendingColorScheme ?? colorSchemeForAppearance(appearance))
            .overlay(
                Color.clear
                .background(
                    LinearGradient(
                        colors: [
                            appearanceOverlayColor.opacity(0.28),
                            appearanceOverlayColor.opacity(0.18),
                            appearanceOverlayColor.opacity(0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .blur(radius: isAppearanceTransitioning ? 10 : 0)
                )
                .opacity(isAppearanceTransitioning ? 1.0 : 0.0)
                .ignoresSafeArea()
                .animation(.interactiveSpring(response: 0.6, dampingFraction: 0.9, blendDuration: 0.2), value: isAppearanceTransitioning)
            )
            .onChange(of: appearance) { oldValue, newValue in
                let target: Color
                switch newValue {
                case "light": target = .white
                case "dark": target = .black
                default:
                    if UITraitCollection.current.userInterfaceStyle == .dark {
                        target = .black
                    } else {
                        target = .white
                    }
                }

                // Begin crossfade overlay
                appearanceOverlayColor = target
                withAnimation(.easeInOut(duration: 0.22)) {
                    isAppearanceTransitioning = true
                }

                // Switch the scheme halfway through the overlay fade-in for smoother perception
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                    pendingColorScheme = colorSchemeForAppearance(newValue)

                    #if os(iOS)
                    let generator = UIImpactFeedbackGenerator(style: .soft)
                    generator.impactOccurred(intensity: 0.35)
                    #endif

                    // Fade overlay out after the scheme has changed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        withAnimation(.easeInOut(duration: 0.26)) {
                            isAppearanceTransitioning = false
                        }
                        // Clear overlay color and pending scheme after animation completes to avoid retaining state
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            appearanceOverlayColor = .clear
                            pendingColorScheme = nil
                        }
                    }
                }
            }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { oldValue, newValue in
            if newValue == .active {
                Task { @MainActor in
                    NotificationManager.shared.resetBadge(clearDelivered: true)
                }
            }
        }
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
    
    private func colorSchemeForAppearance(_ key: String) -> ColorScheme? {
        switch key {
        case "light": return .light
        case "dark": return .dark
        default: return nil // system
        }
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
        // If this is a test notification, present as a normal system banner with sound and badge
        let isTest = (notification.request.content.userInfo["isTest"] as? Bool) == true
                  || notification.request.identifier.hasPrefix("test_notification_")
        if isTest {
            completionHandler([.banner, .sound, .badge])
            return
        }

        // For regular reminders, show in-app notification and avoid system banner/sound
        Task { @MainActor in
            await triggerInAppNotification(from: notification)
        }
        // Still show badge only, no system banner or sound
        completionHandler([.badge])
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

