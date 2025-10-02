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
    @State private var animateGlow = false
    @State private var cardScale = 0.9
    @State private var isDisappearing = false
    @State private var disappearDirection: DisappearDirection = .none
    
    enum DisappearDirection {
        case none
        case slideUp
        case slideRight
        case slideLeft
    }
    
    var body: some View {
        if inAppNotificationManager.showingNotification && !inAppNotificationManager.activeNotifications.isEmpty {
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 20) {
                    // Modern header with gradient icon
                    VStack(spacing: 12) {
                        ZStack {
                            // Glowing background
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [.blue.opacity(0.3), .purple.opacity(0.1), .clear],
                                        center: .center,
                                        startRadius: 5,
                                        endRadius: 30
                                    )
                                )
                                .frame(width: 60, height: 60)
                                .scaleEffect(animateGlow ? 1.2 : 1.0)
                                .opacity(animateGlow ? 0.7 : 0.4)
                                .animation(
                                    .easeInOut(duration: 2)
                                    .repeatForever(autoreverses: true),
                                    value: animateGlow
                                )
                            
                            // Bell icon
                            Image(systemName: "bell.fill")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        
                        VStack(spacing: 4) {
                            Text("Reminder")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            if inAppNotificationManager.activeNotifications.count > 1 {
                                Text("\(currentIndex + 1) of \(inAppNotificationManager.activeNotifications.count)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background {
                                        Capsule()
                                            .fill(.secondary.opacity(0.1))
                                    }
                            }
                        }
                    }
                    
                    // Current reminder content with glass effect
                    if currentIndex < inAppNotificationManager.activeNotifications.count {
                        let currentReminder = inAppNotificationManager.activeNotifications[currentIndex]
                        
                        VStack(spacing: 16) {
                            // Reminder details
                            VStack(alignment: .center, spacing: 12) {
                                Text(currentReminder.title)
                                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)
                                
                                VStack(spacing: 8) {
                                    Label {
                                        Text("Due: \(formattedDateTime(currentReminder.timestamp))")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.secondary)
                                    } icon: {
                                        Image(systemName: "clock")
                                            .foregroundColor(.blue)
                                    }
                                    
                                    if currentReminder.repeatFrequency != .none {
                                        Label {
                                            Text(currentReminder.repeatFrequency.displayName)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.secondary)
                                        } icon: {
                                            Image(systemName: "repeat")
                                                .foregroundColor(.purple)
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.regularMaterial)
                                    .stroke(.secondary.opacity(0.2), lineWidth: 1)
                            }
                            
                            // Modern action buttons
                            VStack(spacing: 12) {
                                // Primary actions
                                HStack(spacing: 12) {
                                    modernCompleteButton
                                    modernSnoozeMenu
                                }
                                
                                // Secondary actions (if multiple notifications)
                                if inAppNotificationManager.activeNotifications.count > 1 {
                                    HStack(spacing: 12) {
                                        modernNextButton
                                        modernCompleteAllButton
                                    }
                                }
                            }
                        }
                    }
                    
                    // Close button
                    Button {
                        dismissCurrentNotification()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 28, height: 28)
                            .background {
                                Circle()
                                    .fill(.regularMaterial)
                                    .stroke(.secondary.opacity(0.3), lineWidth: 1)
                            }
                    }
                }
                .padding(24)
                .background {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                        .overlay {
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        }
                }
                .padding(.horizontal, 20)
                .scaleEffect(isDisappearing ? 0.8 : cardScale)
                .offset(
                    x: isDisappearing ? (disappearDirection == .slideRight ? 400 : (disappearDirection == .slideLeft ? -400 : 0)) : 0,
                    y: isDisappearing ? (disappearDirection == .slideUp ? -200 : 0) : 0
                )
                .opacity(isDisappearing ? 0 : 1)
                .onAppear {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        cardScale = 1.0
                    }
                    animateGlow = true
                }
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.8)),
                        removal: .opacity.combined(with: .scale(scale: 0.8))
                    )
                )
                
                Spacer()
                    .frame(height: 120)
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: inAppNotificationManager.showingNotification)
            .animation(.easeInOut(duration: 0.3), value: currentIndex)
        }
    }
    
    // MARK: - Modern Button Components
    
    private var modernCompleteButton: some View {
        Button {
            completeCurrentReminder()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                Text("Complete")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
        }
    }
    
    private var modernSnoozeMenu: some View {
        Menu {
            Button("5 minutes") { snoozeCurrentReminder(minutes: 5) }
            Button("10 minutes") { snoozeCurrentReminder(minutes: 10) }
            Button("15 minutes") { snoozeCurrentReminder(minutes: 15) }
            Button("30 minutes") { snoozeCurrentReminder(minutes: 30) }
            Button("1 hour") { snoozeCurrentReminder(minutes: 60) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16, weight: .medium))
                Text("Snooze")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
        }
    }
    
    private var modernNextButton: some View {
        Button {
            showNextNotification()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                Text("Next")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.regularMaterial)
                    .stroke(.secondary.opacity(0.3), lineWidth: 1)
            }
        }
    }
    
    private var modernCompleteAllButton: some View {
        Button {
            completeAllNotifications()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 16, weight: .medium))
                Text("Complete All")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
        }
    }
    
    // MARK: - Helper Methods

    private func completeAllNotifications() {
        // Complete all active reminders using the manager
        let toComplete = inAppNotificationManager.activeNotifications
        guard !toComplete.isEmpty else { return }
        // Animate disappearance
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isDisappearing = true
            disappearDirection = .slideUp
        }
        for reminder in toComplete {
            inAppNotificationManager.completeReminder(reminder)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isDisappearing = false
            disappearDirection = .none
            currentIndex = 0
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
        
        // Animate the card sliding up and disappearing
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            disappearDirection = .slideUp
            isDisappearing = true
        }
        
        // Complete the reminder immediately to ensure state is updated
        inAppNotificationManager.completeReminder(reminder)
        
        // Reset animation state and adjust index after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isDisappearing = false
            disappearDirection = .none
            adjustCurrentIndex()
        }
    }
    
    private func snoozeCurrentReminder(minutes: Int) {
        guard currentIndex < inAppNotificationManager.activeNotifications.count else { return }
        let reminder = inAppNotificationManager.activeNotifications[currentIndex]
        
        // Animate the card sliding right and disappearing
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            disappearDirection = .slideRight
            isDisappearing = true
        }
        
        // Snooze the reminder immediately to ensure state is updated
        inAppNotificationManager.snoozeReminder(reminder, minutes: minutes)
        
        // Reset animation state and adjust index after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isDisappearing = false
            disappearDirection = .none
            adjustCurrentIndex()
        }
    }
    
    private func dismissCurrentNotification() {
        guard currentIndex < inAppNotificationManager.activeNotifications.count else { return }
        let reminder = inAppNotificationManager.activeNotifications[currentIndex]
        
        // Animate the card sliding left and disappearing
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            disappearDirection = .slideLeft
            isDisappearing = true
        }
        
        // Dismiss the notification immediately to ensure state is updated
        inAppNotificationManager.dismissNotification(reminder)
        
        // Reset animation state and adjust index after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isDisappearing = false
            disappearDirection = .none
            adjustCurrentIndex()
        }
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
