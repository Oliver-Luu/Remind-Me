//
//  ContentView.swift
//  Remind Me
//
//  Created by Oliver Luu on 9/22/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var notificationManager: NotificationManager
    @State private var isPresentingAddReminder = false
    @State private var showingNotificationAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("iRemindMe")
                    .font(.system(size: 56, weight: .bold, design: .monospaced))
                    .padding(.top, 46)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(formattedTime(context.date))
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                        .padding(.top, 4)
                    Text(formattedDate(context.date))
                        .font(.system(size: 25, weight: .bold, design: .monospaced))
                        .padding(.top, 4)
                }

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

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("j:mm:ss")
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM dd"
        return formatter
    }()

    private func formattedTime(_ date: Date) -> String {
        return ContentView.timeFormatter.string(from: date)
    }

    private func formattedDate(_ date: Date) -> String {
        return ContentView.dateFormatter.string(from: date)
    }
}

#Preview {
    ContentView()
        .environmentObject(NotificationManager.shared)
        .environmentObject(InAppNotificationManager())
        .modelContainer(for: Item.self, inMemory: true)
}
