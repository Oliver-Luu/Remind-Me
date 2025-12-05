import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("settings.inAppSound") private var inAppSound: String = "default"
    @AppStorage("settings.pushSound") private var pushSound: String = "default"
    @AppStorage("settings.hapticsLevel") private var hapticsLevel: String = HapticLevel.system.rawValue
    @AppStorage("settings.appearance") private var appearance: String = "system"
    @EnvironmentObject private var notificationManager: NotificationManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext
    
    private static let deletedItemsSort: [SortDescriptor<Item>] = [
        SortDescriptor(\Item.timestamp, order: .reverse)
    ]
    private static let deletedItemsFilter: Predicate<Item> = #Predicate<Item> { item in
        item.isInDeleteBin
    }
    @Query(filter: Self.deletedItemsFilter, sort: Self.deletedItemsSort) private var deletedItems: [Item]
    
    // Dynamic Type scaling properties
    private var dynamicSectionSpacing: CGFloat {
        24 * min(dynamicTypeSize.scaleFactor, 1.2)
    }
    
    private var dynamicFormSpacing: CGFloat {
        20 * min(dynamicTypeSize.scaleFactor, 1.2)
    }
    
    private var dynamicTopPadding: CGFloat {
        32 * min(dynamicTypeSize.scaleFactor, 1.2)
    }
    
    private var dynamicHorizontalPadding: CGFloat {
        20 * min(dynamicTypeSize.scaleFactor, 1.2)
    }
    
    private var dynamicMenuSpacing: CGFloat {
        16 * min(dynamicTypeSize.scaleFactor, 1.2)
    }
    
    private var dynamicMenuPadding: CGFloat {
        max(12, 12 * min(dynamicTypeSize.scaleFactor, 1.2))
    }
    
    private var dynamicButtonSpacing: CGFloat {
        10 * min(dynamicTypeSize.scaleFactor, 1.2)
    }
    
    private var dynamicButtonVerticalPadding: CGFloat {
        14 * min(dynamicTypeSize.scaleFactor, 1.2)
    }
    
    private var dynamicMenuTitleSize: CGFloat {
        14 * min(dynamicTypeSize.scaleFactor, 1.2)
    }
    
    private var dynamicMenuValueSize: CGFloat {
        16 * min(dynamicTypeSize.scaleFactor, 1.2)
    }
    
    private var dynamicMenuIconSize: CGFloat {
        12 * min(dynamicTypeSize.scaleFactor, 1.2)
    }
    
    private var dynamicButtonTitleSize: CGFloat {
        16 * min(dynamicTypeSize.scaleFactor, 1.2)
    }
    
    private var dynamicButtonIconSize: CGFloat {
        16 * min(dynamicTypeSize.scaleFactor, 1.2)
    }

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
                    VStack(spacing: dynamicSectionSpacing) {
                        VStack(spacing: dynamicFormSpacing) {
                            ModernFormSection(title: "In-App Notifications") {
                                VStack(spacing: 16 * min(dynamicTypeSize.scaleFactor, 1.2)) {
                                    Menu {
                                        Button("Default (Bell)") { inAppSound = "default"; Haptics.impact(.light) }
                                        Button("Tri-tone") { inAppSound = "triTone"; Haptics.impact(.light) }
                                        Button("Bell") { inAppSound = "bell"; Haptics.impact(.light) }
                                        Button("None") { inAppSound = "none"; Haptics.impact(.light) }
                                    } label: {
                                        HStack(spacing: dynamicMenuSpacing) {
                                            Text("Sound")
                                                .font(.system(size: dynamicMenuTitleSize, weight: .medium))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.9)
                                            Spacer()
                                            HStack(spacing: 8 * min(dynamicTypeSize.scaleFactor, 1.2)) {
                                                Text(labelForInApp(inAppSound))
                                                    .font(.system(size: dynamicMenuValueSize, weight: .medium))
                                                    .foregroundColor(.primary)
                                                    .lineLimit(2)
                                                    .multilineTextAlignment(.trailing)
                                                    .minimumScaleFactor(0.8)
                                                Image(systemName: "chevron.up.chevron.down")
                                                    .font(.system(size: dynamicMenuIconSize, weight: .medium))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(.horizontal, dynamicMenuPadding + 4)
                                        .padding(.vertical, dynamicMenuPadding)
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
                                        HStack(spacing: dynamicButtonSpacing) {
                                            Image(systemName: "speaker.wave.2.fill")
                                                .font(.system(size: dynamicButtonIconSize, weight: .semibold))
                                            Text("Play Test Sound")
                                                .font(.system(size: dynamicButtonTitleSize, weight: .semibold, design: .rounded))
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.8)
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, dynamicButtonVerticalPadding)
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
                                VStack(spacing: 16 * min(dynamicTypeSize.scaleFactor, 1.2)) {
                                    Menu {
                                        Button("Default") { pushSound = "default"; Haptics.impact(.light) }
                                        Button("None") { pushSound = "none"; Haptics.impact(.light) }
                                    } label: {
                                        HStack(spacing: dynamicMenuSpacing) {
                                            Text("Sound")
                                                .font(.system(size: dynamicMenuTitleSize, weight: .medium))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.9)
                                            Spacer()
                                            HStack(spacing: 8 * min(dynamicTypeSize.scaleFactor, 1.2)) {
                                                Text(labelForPush(pushSound))
                                                    .font(.system(size: dynamicMenuValueSize, weight: .medium))
                                                    .foregroundColor(.primary)
                                                    .lineLimit(2)
                                                    .multilineTextAlignment(.trailing)
                                                    .minimumScaleFactor(0.8)
                                                Image(systemName: "chevron.up.chevron.down")
                                                    .font(.system(size: dynamicMenuIconSize, weight: .medium))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(.horizontal, dynamicMenuPadding + 4)
                                        .padding(.vertical, dynamicMenuPadding)
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
                                        HStack(spacing: dynamicButtonSpacing) {
                                            Image(systemName: "bell.badge.fill")
                                                .font(.system(size: dynamicButtonIconSize, weight: .semibold))
                                            Text("Play Test Notification")
                                                .font(.system(size: dynamicButtonTitleSize, weight: .semibold, design: .rounded))
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.8)
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, dynamicButtonVerticalPadding)
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
                                VStack(spacing: 16 * min(dynamicTypeSize.scaleFactor, 1.2)) {
                                    Menu {
                                        Button("Off") { hapticsLevel = HapticLevel.off.rawValue; Haptics.impact(.light) }
                                        Button("Light") { hapticsLevel = HapticLevel.light.rawValue; Haptics.impact(.light) }
                                        Button("Medium") { hapticsLevel = HapticLevel.medium.rawValue; Haptics.impact(.light) }
                                        Button("Heavy") { hapticsLevel = HapticLevel.heavy.rawValue; Haptics.impact(.light) }
                                    } label: {
                                        HStack(spacing: dynamicMenuSpacing) {
                                            Text("Feedback Level")
                                                .font(.system(size: dynamicMenuTitleSize, weight: .medium))
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                                .minimumScaleFactor(0.9)
                                            Spacer()
                                            HStack(spacing: 8 * min(dynamicTypeSize.scaleFactor, 1.2)) {
                                                Text(labelForHaptics(hapticsLevel))
                                                    .font(.system(size: dynamicMenuValueSize, weight: .medium))
                                                    .foregroundColor(.primary)
                                                    .lineLimit(2)
                                                    .multilineTextAlignment(.trailing)
                                                    .minimumScaleFactor(0.8)
                                                Image(systemName: "chevron.up.chevron.down")
                                                    .font(.system(size: dynamicMenuIconSize, weight: .medium))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(.horizontal, dynamicMenuPadding + 4)
                                        .padding(.vertical, dynamicMenuPadding)
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
                                        HStack(spacing: dynamicButtonSpacing) {
                                            Image(systemName: "hand.tap.fill")
                                                .font(.system(size: dynamicButtonIconSize, weight: .semibold))
                                            Text("Play Test Haptic")
                                                .font(.system(size: dynamicButtonTitleSize, weight: .semibold, design: .rounded))
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.8)
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, dynamicButtonVerticalPadding)
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
                                VStack(spacing: 16 * min(dynamicTypeSize.scaleFactor, 1.2)) {
                                    Menu {
                                        Button("System") { appearance = "system"; Haptics.selectionChanged() }
                                        Button("Light") { appearance = "light"; Haptics.selectionChanged() }
                                        Button("Dark") { appearance = "dark"; Haptics.selectionChanged() }
                                    } label: {
                                        HStack(spacing: dynamicMenuSpacing) {
                                            Text("Theme")
                                                .font(.system(size: dynamicMenuTitleSize, weight: .medium))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.9)
                                            Spacer()
                                            HStack(spacing: 8 * min(dynamicTypeSize.scaleFactor, 1.2)) {
                                                Text(appearanceLabel(appearance))
                                                    .font(.system(size: dynamicMenuValueSize, weight: .medium))
                                                    .foregroundColor(.primary)
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.8)
                                                Image(systemName: "chevron.up.chevron.down")
                                                    .font(.system(size: dynamicMenuIconSize, weight: .medium))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(.horizontal, dynamicMenuPadding + 4)
                                        .padding(.vertical, dynamicMenuPadding)
                                        .background {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(.regularMaterial)
                                                .stroke(.secondary.opacity(0.3), lineWidth: 1)
                                        }
                                    }
                                    .menuStyle(.automatic)
                                }
                            }
                            
                            ModernFormSection(title: "Recently Deleted") {
                                if deletedItems.isEmpty {
                                    Text("No reminders in bin")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: dynamicMenuValueSize))
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.vertical, dynamicMenuPadding)
                                } else {
                                    ForEach(deletedItems, id: \.id) { item in
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.title)
                                                    .font(.system(size: dynamicMenuValueSize, weight: .medium))
                                                    .foregroundColor(.primary)
                                                    .lineLimit(1)
                                                Text(item.timestamp, style: .date)
                                                    .font(.system(size: dynamicMenuTitleSize))
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            Button(role: .destructive) {
                                                modelContext.delete(item)
                                                do {
                                                    try modelContext.save()
                                                } catch {
                                                    // Handle save error if necessary
                                                }
                                            } label: {
                                                Text("Delete")
                                                    .font(.system(size: dynamicMenuTitleSize, weight: .semibold))
                                            }
                                            .buttonStyle(BorderlessButtonStyle())
                                        }
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, dynamicMenuPadding)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(.regularMaterial)
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.top, dynamicTopPadding)
                        .padding(.horizontal, dynamicHorizontalPadding)
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
                    topPadding: 32,
                    fontScale: min(dynamicTypeSize.scaleFactor, 1.1)
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

