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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var settingsButtonScale = 1.0
    @State private var settingsHapticFired = false

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
                        let maxButtonSize: CGFloat = 36
                        let iconSize = min(dynamicIconSize(for: 16), 28)
                        let buttonSize = maxButtonSize
                        ZStack {
                            // Background circle that scales appropriately with Dynamic Type
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: buttonSize, height: buttonSize)
                                .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                            
                            // Icon that scales with Dynamic Type up to "large" size
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: iconSize, weight: .semibold))
                                .foregroundColor(.white)
                                .scaleEffect(settingsButtonScale)
                        }
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if !settingsHapticFired {
                                    Haptics.impact(.light)
                                    settingsHapticFired = true
                                }
                                withAnimation(.easeInOut(duration: 0.08)) {
                                    settingsButtonScale = 0.94
                                }
                            }
                            .onEnded { _ in
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    settingsButtonScale = 1.0
                                }
                                settingsHapticFired = false
                            }
                    )
                    .accessibilityLabel("Settings")
                    .accessibilityHint("Opens app settings")
                }
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        TrashView().modifier(BackHapticToolbar())
                    } label: {
                        let maxButtonSize: CGFloat = 36
                        let iconSize = min(dynamicIconSize(for: 16), 28)
                        let buttonSize = maxButtonSize
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.gray, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: buttonSize, height: buttonSize)
                                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                            Image(systemName: "trash")
                                .font(.system(size: iconSize, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Recently Deleted")
                    .accessibilityHint("Opens the trash to restore reminders")
                }
            }
        }
    }
    
    // Dynamic Type scaling helpers
    private func dynamicIconSize(for baseSize: CGFloat) -> CGFloat {
        let scaleFactor = min(dynamicTypeSize.scaleFactor, 1.4) // Cap increased to 1.4
        return baseSize * scaleFactor
    }
    
    private func dynamicButtonSize(for baseSize: CGFloat) -> CGFloat {
        let maxButtonSize: CGFloat = 44
        return maxButtonSize
    }

}

// MARK: - Supporting View Components

struct HeaderSection: View {
    let screenWidth: CGFloat
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    private var dynamicIconSize: CGFloat {
        let baseSize: CGFloat
        switch screenWidth {
        case ..<340: baseSize = 100
        case ..<390: baseSize = 110
        case ..<430: baseSize = 120
        case ..<600: baseSize = 130
        default: baseSize = 140
        }
        return baseSize * dynamicTypeSize.scaleFactor
    }
    
    private var dynamicTitleSize: CGFloat {
        let baseSize: CGFloat
        switch screenWidth {
        case ..<340: baseSize = 36
        case ..<390: baseSize = 40
        case ..<430: baseSize = 44
        case ..<600: baseSize = 48
        default: baseSize = 52
        }
        return baseSize * dynamicTypeSize.scaleFactor
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
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .allowsTightening(true)
        }
        .padding(.horizontal)
    }
}

struct TimeDisplaySection: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    private var dynamicTimeSize: CGFloat {
        36 * dynamicTypeSize.scaleFactor
    }
    
    private var dynamicDateSize: CGFloat {
        18 * dynamicTypeSize.scaleFactor
    }
    
    private var dynamicPadding: CGFloat {
        24 * dynamicTypeSize.scaleFactor
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Glass container for time display
            VStack(spacing: 8) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(spacing: 4) {
                        Text(formattedTime(context.date))
                            .font(.system(size: dynamicTimeSize, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        
                        Text(formattedDate(context.date))
                            .font(.system(size: dynamicDateSize, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
            .padding(.horizontal, dynamicPadding)
            .padding(.vertical, 16 * dynamicTypeSize.scaleFactor)
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20 * dynamicTypeSize.scaleFactor, weight: .medium))
                .foregroundColor(.orange)
                .scaleEffect(bounceAlert ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: bounceAlert)
                .onAppear {
                    bounceAlert = true
                }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Notifications Disabled")
                    .font(.system(size: 14 * dynamicTypeSize.scaleFactor, weight: .semibold))
                    .foregroundColor(.orange)
                
                Text("Enable in iOS System Settings for full functionality")
                    .font(.system(size: UIFont.preferredFont(forTextStyle: .caption1).pointSize * dynamicTypeSize.scaleFactor))
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16 * dynamicTypeSize.scaleFactor)
        .padding(.vertical, 12 * dynamicTypeSize.scaleFactor)
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    @State private var remindersButtonScale = 1.0
    @State private var addButtonScale = 1.0
    @State private var calendarButtonScale = 1.0
    @State private var remindersHapticFired = false
    
    private var dynamicIconSize: CGFloat {
        let cappedScale = min(dynamicTypeSize.scaleFactor, 1.3)
        return 20 * cappedScale
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // My Reminders Button with glass effect
            NavigationLink {
                RemindersListView().modifier(BackHapticToolbar())
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: dynamicIconSize, weight: .medium))
                    
                    Text("My Reminders")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.semibold)
                        .lineLimit(dynamicTypeSize.scaleFactor >= 1.6 ? 2 : 1)
                        .minimumScaleFactor(dynamicTypeSize.scaleFactor >= 1.6 ? 1.0 : 0.8)
                        .multilineTextAlignment(.leading)
                        .allowsTightening(true)
                        .layoutPriority(1)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20 * dynamicTypeSize.scaleFactor)
                .padding(.vertical, 16 * dynamicTypeSize.scaleFactor)
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
                        .font(.system(size: dynamicIconSize, weight: .medium))

                    Text("Calendar View")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.semibold)
                        .lineLimit(dynamicTypeSize.scaleFactor >= 1.6 ? 2 : 1)
                        .minimumScaleFactor(dynamicTypeSize.scaleFactor >= 1.6 ? 1.0 : 0.8)
                        .multilineTextAlignment(.leading)
                        .allowsTightening(true)
                        .layoutPriority(1)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20 * dynamicTypeSize.scaleFactor)
                .padding(.vertical, 18 * dynamicTypeSize.scaleFactor)
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
                        .font(.system(size: dynamicIconSize, weight: .medium))
                    
                    Text("Add Reminder")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.semibold)
                        .lineLimit(dynamicTypeSize.scaleFactor >= 1.6 ? 2 : 1)
                        .minimumScaleFactor(dynamicTypeSize.scaleFactor >= 1.6 ? 1.0 : 0.8)
                        .multilineTextAlignment(.leading)
                        .allowsTightening(true)
                        .layoutPriority(1)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16 * dynamicTypeSize.scaleFactor)
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
                            .font(.system(size: min(18, 18 * dynamicTypeSize.scaleFactor), weight: .semibold))
                            .frame(width: 44, height: 44, alignment: .center) // Standard touch target
                            .contentShape(Circle())
                            .accessibilityLabel("Back")
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(InteractivePopGestureEnabler())
    }
}

// MARK: - Dynamic Type Extension

extension DynamicTypeSize {
    /// Returns a scale factor based on the dynamic type size
    /// Medium (default) returns 1.0, smaller sizes return values < 1.0, larger sizes return values > 1.0
    var scaleFactor: CGFloat {
        switch self {
        case .xSmall:
            return 0.9
        case .small:
            return 1.0
        case .medium:
            return 1.15 // New baseline: was 1.0
        case .large:
            return 1.3
        case .xLarge:
            return 1.4
        case .xxLarge:
            return 1.5
        case .xxxLarge:
            return 1.6
        case .accessibility1:
            return 1.8
        case .accessibility2:
            return 2.0
        case .accessibility3:
            return 2.2
        case .accessibility4:
            return 2.4
        case .accessibility5:
            return 2.6
        @unknown default:
            return 1.15
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(NotificationManager.shared)
        .environmentObject(InAppNotificationManager())
        .modelContainer(for: Item.self, inMemory: true)
}

