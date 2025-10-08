import SwiftUI

struct SettingsView: View {
    @AppStorage("settings.inAppSound") private var inAppSound: String = "default"
    @AppStorage("settings.pushSound") private var pushSound: String = "default"
    @AppStorage("settings.hapticsLevel") private var hapticsLevel: String = HapticLevel.system.rawValue
    @AppStorage("settings.appearance") private var appearance: String = "system"
    @EnvironmentObject private var notificationManager: NotificationManager

    private func labelForInApp(_ key: String) -> String {
        switch key {
        case "default": return "Default (Bell)"
        case "triTone": return "Tri-tone"
        case "bell": return "Bell"
        case "none": return "None"
        default: return "Default (Bell)"
        }
    }

    private func labelForPush(_ key: String) -> String {
        switch key {
        case "default": return "Default"
        case "none": return "None"
        default: return "Default"
        }
    }

    private var hapticLevelOptions: [(key: String, label: String)] {
        [
            (HapticLevel.system.rawValue, "System default"),
            (HapticLevel.light.rawValue, "Light"),
            (HapticLevel.medium.rawValue, "Medium"),
            (HapticLevel.heavy.rawValue, "Heavy"),
            (HapticLevel.off.rawValue, "Off")
        ]
    }

    private func labelForHaptics(_ key: String) -> String {
        hapticLevelOptions.first(where: { $0.key == key })?.label ?? "System default"
    }

    private func appearanceLabel(_ key: String) -> String {
        switch key {
        case "light": return "Light"
        case "dark": return "Dark"
        default: return "System"
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CrossingRadialBackground(
                    colorsA: [
                        Color.blue.opacity(0.18),
                        Color.purple.opacity(0.12),
                        Color.clear
                    ],
                    colorsB: [
                        Color.purple.opacity(0.16),
                        Color.blue.opacity(0.10),
                        Color.clear
                    ],
                    startCenterA: .topLeading,
                    endCenterA: .bottomTrailing,
                    startCenterB: .bottomTrailing,
                    endCenterB: .topLeading,
                    startRadius: 40,
                    endRadius: 350,
                    duration: 10,
                    autoreverses: true
                )

                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 20) {
                            ModernFormSection(title: "In-App Notifications") {
                                VStack(spacing: 16) {
                                    Menu {
                                        Button("Default (Bell)") { inAppSound = "default"; Haptics.impact(.light) }
                                        Button("Tri-tone") { inAppSound = "triTone"; Haptics.impact(.light) }
                                        Button("Bell") { inAppSound = "bell"; Haptics.impact(.light) }
                                        Button("None") { inAppSound = "none"; Haptics.impact(.light) }
                                    } label: {
                                        HStack(spacing: 16) {
                                            Text("Sound")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            HStack(spacing: 8) {
                                                Text(labelForInApp(inAppSound))
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(.primary)
                                                Image(systemName: "chevron.up.chevron.down")
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(.regularMaterial)
                                                .stroke(.secondary.opacity(0.3), lineWidth: 1)
                                        }
                                    }
                                    .menuStyle(.automatic)

                                    Button {
                                        NotificationSoundPlayer.shared.playReminderSound()
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: "speaker.wave.2.fill")
                                                .font(.system(size: 16, weight: .semibold))
                                            Text("Play Test Sound")
                                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background {
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [.blue, .purple],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                                .shadow(color: .blue.opacity(0.25), radius: 10, x: 0, y: 5)
                                        }
                                    }
                                }
                            }

                            ModernFormSection(title: "System Notifications") {
                                VStack(spacing: 16) {
                                    Menu {
                                        Button("Default") { pushSound = "default"; Haptics.impact(.light) }
                                        Button("None") { pushSound = "none"; Haptics.impact(.light) }
                                    } label: {
                                        HStack(spacing: 16) {
                                            Text("Sound")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            HStack(spacing: 8) {
                                                Text(labelForPush(pushSound))
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(.primary)
                                                Image(systemName: "chevron.up.chevron.down")
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(.regularMaterial)
                                                .stroke(.secondary.opacity(0.3), lineWidth: 1)
                                        }
                                    }
                                    .menuStyle(.automatic)

                                    Button {
                                        Task { await notificationManager.scheduleTestNotification() }
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: "bell.badge.fill")
                                                .font(.system(size: 16, weight: .semibold))
                                            Text("Play Test Notification")
                                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background {
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [.indigo, .blue],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                                .shadow(color: .blue.opacity(0.25), radius: 10, x: 0, y: 5)
                                        }
                                    }

                                    if notificationManager.authorizationStatus == .denied {
                                        ModernStatusRow(
                                            icon: "exclamationmark.triangle.fill",
                                            iconColor: .orange,
                                            text: "Notifications are disabled in Settings"
                                        )
                                    }
                                }
                            }

                            ModernFormSection(title: "Haptics") {
                                VStack(spacing: 16) {
                                    Menu {
                                        Button("Off") { hapticsLevel = HapticLevel.off.rawValue; Haptics.impact(.light) }
                                        Button("Light") { hapticsLevel = HapticLevel.light.rawValue; Haptics.impact(.light) }
                                        Button("Medium") { hapticsLevel = HapticLevel.medium.rawValue; Haptics.impact(.light) }
                                        Button("Heavy") { hapticsLevel = HapticLevel.heavy.rawValue; Haptics.impact(.light) }
                                    } label: {
                                        HStack(spacing: 16) {
                                            Text("Feedback Level")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            HStack(spacing: 8) {
                                                Text(labelForHaptics(hapticsLevel))
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(.primary)
                                                Image(systemName: "chevron.up.chevron.down")
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(.regularMaterial)
                                                .stroke(.secondary.opacity(0.3), lineWidth: 1)
                                        }
                                    }
                                    .menuStyle(.automatic)

                                    Button {
                                        // Play a test haptic matching selection
                                        if let level = HapticLevel(rawValue: hapticsLevel) {
                                            switch level {
                                            case .off:
                                                // No haptic
                                                break
                                            case .light:
                                                Haptics.impact(.light)
                                            case .medium:
                                                Haptics.impact(.medium)
                                            case .heavy:
                                                Haptics.impact(.heavy)
                                            case .system:
                                                Haptics.selectionChanged()
                                            }
                                        } else {
                                            Haptics.selectionChanged()
                                        }
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: "hand.tap.fill")
                                                .font(.system(size: 16, weight: .semibold))
                                            Text("Play Test Haptic")
                                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background {
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [.purple, .pink],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                                .shadow(color: .purple.opacity(0.25), radius: 10, x: 0, y: 5)
                                        }
                                    }
                                }
                            }

                            ModernFormSection(title: "Appearance") {
                                VStack(spacing: 16) {
                                    Menu {
                                        Button("System") { appearance = "system"; Haptics.selectionChanged() }
                                        Button("Light") { appearance = "light"; Haptics.selectionChanged() }
                                        Button("Dark") { appearance = "dark"; Haptics.selectionChanged() }
                                    } label: {
                                        HStack(spacing: 16) {
                                            Text("Theme")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            HStack(spacing: 8) {
                                                Text(appearanceLabel(appearance))
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(.primary)
                                                Image(systemName: "chevron.up.chevron.down")
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(.regularMaterial)
                                                .stroke(.secondary.opacity(0.3), lineWidth: 1)
                                        }
                                    }
                                    .menuStyle(.automatic)
                                }
                            }
                        }
                        .padding(.top, 32)
                        .padding(.horizontal, 20)
                        .frame(minHeight: geometry.size.height - 100)
                    }
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                TitleBarView(
                    title: "Settings",
                    iconSystemName: "gearshape.fill",
                    gradientColors: [.blue, .purple],
                    topPadding: 32
                )
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(NotificationManager.shared)
            .environmentObject(InAppNotificationManager())
    }
}
