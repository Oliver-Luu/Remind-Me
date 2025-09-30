//
//  ContentView.swift
//  Remind Me
//
//  Created by Oliver Luu on 9/22/25.
//

import SwiftUI
import SwiftData
import Combine

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var notificationManager: NotificationManager
    @EnvironmentObject private var inAppNotificationManager: InAppNotificationManager
    @Query private var items: [Item]
    @State private var currentTime = Date()
    @State private var isTicking = true
    @State private var isPresentingAddReminder = false
    @State private var showingNotificationAlert = false
        
    // Timer that fires every second
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("iRemindMe")
                    .font(.system(size: 56, weight: .bold, design: .monospaced))
                    .padding(.top, 46)
                Text(formattedTime)
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .padding(.top, 4)
                Text(formattedDate)
                    .font(.system(size: 25, weight: .bold, design: .monospaced))
                    .padding(.top, 4)
                
                // Notification status indicator
                if notificationManager.authorizationStatus == .denied {
                    VStack(spacing: 4) {
                        Image(systemName: "bell.slash")
                            .foregroundColor(.orange)
                        Text("Notifications Disabled")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 8)
                }
                
                Spacer()

                VStack(spacing: 16) {
                    NavigationLink("My Reminders") {
                        RemindersListView()
                    }
                    .buttonStyle(.bordered)
                    .frame(minWidth: 240)

                    Button("Add Reminder") {
                        if notificationManager.authorizationStatus == .denied {
                            showingNotificationAlert = true
                        } else {
                            isPresentingAddReminder = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(minWidth: 240)
                    
                }
                .font(.title2)
                .controlSize(.large)
                .frame(maxWidth: .infinity)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // Update the state every time the timer fires
            .onReceive(timer) { input in
                if isTicking {
                    currentTime = input
                }
            }
            .sheet(isPresented: $isPresentingAddReminder) {
                NavigationStack {
                    AddReminderView()
                        .presentationDetents([.large])
                    .presentationDragIndicator(.visible)    // show the little grab bar
                }
            }
            .alert("Enable Notifications", isPresented: $showingNotificationAlert) {
                Button("Settings") {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                Button("Cancel", role: .cancel) { }
                Button("Continue Without Notifications") {
                    isPresentingAddReminder = true
                }
            } message: {
                Text("To receive reminder notifications, please enable notifications in Settings. You can still create reminders without notifications.")
            }
        }
    }

    // Computed property to format time
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss" // 24-hour format
        return formatter.string(from: currentTime)
    }

    // Computed property to format date
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM dd" // e.g., September 24
        return formatter.string(from: currentTime)
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(NotificationManager.shared)
        .environmentObject(InAppNotificationManager())
        .modelContainer(for: Item.self, inMemory: true)
}
