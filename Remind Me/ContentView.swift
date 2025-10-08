//
//  ContentView.swift
//  Remind Me
//
//  Created by Oliver Luu on 9/22/25.
//

import SwiftUI
import SwiftData
import UIKit

struct ContentView: View {
    @EnvironmentObject private var notificationManager: NotificationManager
    @State private var isPresentingAddReminder = false
    @State private var showingNotificationAlert = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Dynamic animated background
                    CrossingRadialBackground(
                        colorsA: [
                            Color.blue.opacity(0.3),
                            Color.purple.opacity(0.2),
                            Color.clear
                        ],
                        colorsB: [
                            Color.purple.opacity(0.4),
                            Color.blue.opacity(0.28),
                            Color.clear
                        ],
                        startCenterA: .bottomTrailing,
                        endCenterA: .topLeading,
                        startCenterB: .topLeading,
                        endCenterB: .bottomTrailing,
                        startRadius: 50,
                        endRadius: 400,
                        duration: 8,
                        autoreverses: true
                    )
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            // Header section with glass effect
                            HeaderSection(screenWidth: geometry.size.width)
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
                    Haptics.impact(.light)
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                Button("Cancel", role: .cancel) {
                    Haptics.impact(.light)
                }
                Button("Continue Without Notifications") {
                    Haptics.impact(.light)
                    isPresentingAddReminder = true
                }
            } message: {
                Text("To receive reminder notifications, please enable notifications in Settings. You can still create reminders without notifications.")
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        SettingsView().modifier(BackHapticToolbar())
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .buttonBorderShape(.circle)
                    .simultaneousGesture(TapGesture().onEnded { Haptics.impact(.light) })
                }
            }
        }
    }

}

// MARK: - Supporting View Components

struct HeaderSection: View {
    let screenWidth: CGFloat
    
    private var dynamicIconSize: CGFloat {
        switch screenWidth {
        case ..<340: return 100
        case ..<390: return 110
        case ..<430: return 120
        case ..<600: return 130
        default: return 140
        }
    }
    
    private var dynamicTitleSize: CGFloat {
        switch screenWidth {
        case ..<340: return 36
        case ..<390: return 40
        case ..<430: return 44
        case ..<600: return 48
        default: return 52
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "bell.circle.fill")
                .font(.system(size: dynamicIconSize, weight: .light))
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
                            .font(.system(size: dynamicIconSize, weight: .light))
                    )
                )
            
            Text("iRemindMe")
                .font(.system(size: dynamicTitleSize, weight: .bold, design: .default))
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
    @State private var calendarButtonScale = 1.0
    @State private var remindersHapticFired = false
    
    var body: some View {
        VStack(spacing: 20) {
            // My Reminders Button with glass effect
            NavigationLink {
                RemindersListView().modifier(BackHapticToolbar())
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: 20, weight: .medium))
                    
                    Text("My Reminders")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [.orange, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: .blue.opacity(0.3), radius: 12, x: 0, y: 6)
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !remindersHapticFired {
                            Haptics.impact(.light)
                            remindersHapticFired = true
                        }
                    }
                    .onEnded { _ in
                        remindersHapticFired = false
                    }
            )
            .scaleEffect(remindersButtonScale)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.1)) {
                    remindersButtonScale = 0.95
                }
                withAnimation(.easeInOut(duration: 0.1).delay(0.1)) {
                    remindersButtonScale = 1.0
                }
            }
            
            // Calendar View Button with glass effect
            NavigationLink {
                CalendarView().modifier(BackHapticToolbar())
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .font(.system(size: 20, weight: .medium))

                    Text("Calendar View")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [.teal, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: .blue.opacity(0.3), radius: 12, x: 0, y: 6)
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !remindersHapticFired {
                            Haptics.impact(.light)
                            remindersHapticFired = true
                        }
                    }
                    .onEnded { _ in
                        remindersHapticFired = false
                    }
            )
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
                Haptics.impact(.medium)
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
                                colors: [.green, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: .blue.opacity(0.3), radius: 12, x: 0, y: 6)
                }
            }
            .buttonStyle(HapticButtonStyle())
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

private struct InteractivePopGestureEnabler: UIViewRepresentable {
    final class PopEnablerView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            enablePopGesture()
        }

        override func didMoveToSuperview() {
            super.didMoveToSuperview()
            enablePopGesture()
        }

        private func enablePopGesture() {
            guard let nav = findNavigationController(from: self) else { return }
            if let gesture = nav.interactivePopGestureRecognizer {
                gesture.isEnabled = true
                gesture.delegate = nil
            }
        }

        private func findNavigationController(from view: UIView) -> UINavigationController? {
            // Walk the responder chain to find a UINavigationController
            var responder: UIResponder? = view
            while let r = responder {
                if let nav = (r as? UIViewController)?.navigationController {
                    return nav
                }
                if let nav = r as? UINavigationController {
                    return nav
                }
                responder = r.next
            }
            return nil
        }
    }

    func makeUIView(context: Context) -> UIView {
        let v = PopEnablerView(frame: .zero)
        v.isUserInteractionEnabled = false
        v.backgroundColor = .clear
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Nothing to update; lifecycle hooks handle enabling the gesture.
    }
}

struct BackHapticToolbar: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptics.impact(.light)
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 44, height: 44, alignment: .center)
                            .contentShape(Circle())
                            .accessibilityLabel("Back")
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(InteractivePopGestureEnabler())
    }
}

#Preview {
    ContentView()
        .environmentObject(NotificationManager.shared)
        .environmentObject(InAppNotificationManager())
        .modelContainer(for: Item.self, inMemory: true)
}

