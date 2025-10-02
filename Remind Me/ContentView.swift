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
    @State private var animateGradient = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Dynamic animated background
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(0.3),
                            Color.purple.opacity(0.2),
                            Color.clear
                        ]),
                        center: animateGradient ? .topLeading : .bottomTrailing,
                        startRadius: 50,
                        endRadius: 400
                    )
                    .ignoresSafeArea()
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 8)
                            .repeatForever(autoreverses: true)
                        ) {
                            animateGradient.toggle()
                        }
                    }
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            // Header section with glass effect
                            HeaderSection()
                                .padding(.top, 20)
                            
                            // Time display section
                            TimeDisplaySection()
                                .padding(.top, 30)
                            
                            // Notification status
                            if notificationManager.authorizationStatus == .denied {
                                NotificationStatusView()
                                    .padding(.top, 20)
                            }
                            
                            Spacer(minLength: 60)
                            
                            // Action buttons section
                            ActionButtonsSection(
                                isPresentingAddReminder: $isPresentingAddReminder,
                                showingNotificationAlert: $showingNotificationAlert,
                                notificationManager: notificationManager
                            )
                            .padding(.bottom, 40)
                        }
                        .frame(minHeight: geometry.size.height)
                    }
                }
            }
            .sheet(isPresented: $isPresentingAddReminder) {
                NavigationStack {
                    AddReminderView()
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
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

}

// MARK: - Supporting View Components

struct HeaderSection: View {
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "bell.circle.fill")
                .font(.system(size: 100, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.16),
                            Color.white.opacity(0.05),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .blendMode(.screen)
                    .mask(
                        Image(systemName: "bell.circle.fill")
                            .font(.system(size: 100, weight: .light))
                    )
                )
            
            Text("iRemindMe")
                .font(.system(size: 42, weight: .bold, design: .default))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .padding(.horizontal)
    }
}

struct TimeDisplaySection: View {
    
    var body: some View {
        VStack(spacing: 12) {
            // Glass container for time display
            VStack(spacing: 8) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(spacing: 4) {
                        Text(formattedTime(context.date))
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        
                        Text(formattedDate(context.date))
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            }
        }
        .padding(.horizontal)
    }
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("j:mm:ss")
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }()

    private func formattedTime(_ date: Date) -> String {
        return TimeDisplaySection.timeFormatter.string(from: date)
    }

    private func formattedDate(_ date: Date) -> String {
        return TimeDisplaySection.dateFormatter.string(from: date)
    }
}

struct NotificationStatusView: View {
    @State private var bounceAlert = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.orange)
                .scaleEffect(bounceAlert ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: bounceAlert)
                .onAppear {
                    bounceAlert = true
                }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Notifications Disabled")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.orange)
                
                Text("Enable in Settings for full functionality")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.orange.opacity(0.1))
                .stroke(.orange.opacity(0.3), lineWidth: 1)
        }
        .padding(.horizontal)
    }
}

struct ActionButtonsSection: View {
    @Binding var isPresentingAddReminder: Bool
    @Binding var showingNotificationAlert: Bool
    let notificationManager: NotificationManager
    
    @State private var remindersButtonScale = 1.0
    @State private var addButtonScale = 1.0
    
    var body: some View {
        VStack(spacing: 20) {
            // My Reminders Button with glass effect
            NavigationLink {
                RemindersListView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: 20, weight: .medium))
                    
                    Text("My Reminders")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                }
            }
            .scaleEffect(remindersButtonScale)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.1)) {
                    remindersButtonScale = 0.95
                }
                withAnimation(.easeInOut(duration: 0.1).delay(0.1)) {
                    remindersButtonScale = 1.0
                }
            }
            
            // Add Reminder Button with prominent styling
            Button {
                if notificationManager.authorizationStatus == .denied {
                    showingNotificationAlert = true
                } else {
                    isPresentingAddReminder = true
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                    
                    Text("Add Reminder")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: .blue.opacity(0.3), radius: 12, x: 0, y: 6)
                }
            }
            .scaleEffect(addButtonScale)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.1)) {
                    addButtonScale = 0.95
                }
                withAnimation(.easeInOut(duration: 0.1).delay(0.1)) {
                    addButtonScale = 1.0
                }
            }
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    ContentView()
        .environmentObject(NotificationManager.shared)
        .environmentObject(InAppNotificationManager())
        .modelContainer(for: Item.self, inMemory: true)
}

