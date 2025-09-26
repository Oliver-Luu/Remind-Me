//
//  InAppNotificationView.swift
//  Remind Me
//
//  Created by Oliver Luu on 9/25/25.
//

import SwiftUI

struct InAppNotificationView: View {
    @ObservedObject var inAppNotificationManager: InAppNotificationManager
    @State private var currentIndex = 0
    
    var body: some View {
        if inAppNotificationManager.showingNotification && !inAppNotificationManager.activeNotifications.isEmpty {
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 16) {
                    // Header
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                        
                        Text("Reminder")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if inAppNotificationManager.activeNotifications.count > 1 {
                            Text("\(currentIndex + 1) of \(inAppNotificationManager.activeNotifications.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Button("✕") {
                            dismissCurrentNotification()
                        }
                        .font(.title3)
                        .foregroundColor(.secondary)
                    }
                    
                    // Current reminder content
                    if currentIndex < inAppNotificationManager.activeNotifications.count {
                        let currentReminder = inAppNotificationManager.activeNotifications[currentIndex]
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(currentReminder.title)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .multilineTextAlignment(.leading)
                            
                            Text("Due: \(formattedDateTime(currentReminder.timestamp))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if currentReminder.repeatFrequency != .none {
                                HStack {
                                    Image(systemName: "repeat")
                                        .font(.caption)
                                    Text(currentReminder.repeatFrequency.displayName)
                                        .font(.caption)
                                }
                                .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Action buttons
                        HStack(spacing: 12) {
                            Button("Complete") {
                                completeCurrentReminder()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            
                            Menu("Snooze") {
                                Button("5 minutes") {
                                    snoozeCurrentReminder(minutes: 5)
                                }
                                Button("10 minutes") {
                                    snoozeCurrentReminder(minutes: 10)
                                }
                                Button("15 minutes") {
                                    snoozeCurrentReminder(minutes: 15)
                                }
                                Button("30 minutes") {
                                    snoozeCurrentReminder(minutes: 30)
                                }
                                Button("1 hour") {
                                    snoozeCurrentReminder(minutes: 60)
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(.orange)
                            
                            Spacer()
                            
                            if inAppNotificationManager.activeNotifications.count > 1 {
                                Button("Next") {
                                    showNextNotification()
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            if inAppNotificationManager.activeNotifications.count > 1 {
                                Button("Dismiss All") {
                                    inAppNotificationManager.dismissAllNotifications()
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            }
                        }
                        .font(.subheadline)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                )
                .padding(.horizontal, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                
                Spacer()
                    .frame(height: 100) // Space from bottom
            }
            .animation(.easeInOut(duration: 0.3), value: inAppNotificationManager.showingNotification)
            .animation(.easeInOut(duration: 0.2), value: currentIndex)
        }
    }
    
    private func formattedDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func completeCurrentReminder() {
        guard currentIndex < inAppNotificationManager.activeNotifications.count else { return }
        let reminder = inAppNotificationManager.activeNotifications[currentIndex]
        inAppNotificationManager.completeReminder(reminder)
        adjustCurrentIndex()
    }
    
    private func snoozeCurrentReminder(minutes: Int) {
        guard currentIndex < inAppNotificationManager.activeNotifications.count else { return }
        let reminder = inAppNotificationManager.activeNotifications[currentIndex]
        inAppNotificationManager.snoozeReminder(reminder, minutes: minutes)
        adjustCurrentIndex()
    }
    
    private func dismissCurrentNotification() {
        guard currentIndex < inAppNotificationManager.activeNotifications.count else { return }
        let reminder = inAppNotificationManager.activeNotifications[currentIndex]
        inAppNotificationManager.dismissNotification(reminder)
        adjustCurrentIndex()
    }
    
    private func showNextNotification() {
        if currentIndex < inAppNotificationManager.activeNotifications.count - 1 {
            currentIndex += 1
        } else {
            currentIndex = 0
        }
    }
    
    private func adjustCurrentIndex() {
        if inAppNotificationManager.activeNotifications.isEmpty {
            currentIndex = 0
        } else if currentIndex >= inAppNotificationManager.activeNotifications.count {
            currentIndex = max(0, inAppNotificationManager.activeNotifications.count - 1)
        }
    }
}

#Preview {
    let manager = InAppNotificationManager()
    
    // Create sample reminders for preview
    let sampleReminder1 = Item(
        timestamp: Date(),
        title: "Take medication",
        repeatFrequency: .daily
    )
    
    let sampleReminder2 = Item(
        timestamp: Date().addingTimeInterval(-60),
        title: "Meeting with John",
        repeatFrequency: .none
    )
    
    manager.activeNotifications = [sampleReminder1, sampleReminder2]
    manager.showingNotification = true
    
    return ZStack {
        Color.blue.ignoresSafeArea()
        
        InAppNotificationView(inAppNotificationManager: manager)
    }
}