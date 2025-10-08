import SwiftUI
import SwiftData

struct AddReminderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var inAppNotificationManager: InAppNotificationManager
    
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true

    @State private var date: Date = Calendar.current.date(byAdding: .minute, value: 1, to: Date()) ?? Date().addingTimeInterval(60)
    @State private var title = ""
    @State private var repeatFrequency = RepeatFrequency.none
    @State private var repeatInterval: Int = 1
    @State private var numberOfOccurrences = 7 // Default number of future reminders to create
    @State private var notificationIntervalMinutes: Int = 1
    @State private var notificationRepeatCount: Int = 10

    @State private var showCustomDatePicker = false
    @State private var customSelectedDates: Set<DateComponents> = []
    @State private var animateGradient = false

    @State private var showInvalidDateAlert = false
    @State private var invalidDateMessage = ""

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dynamic animated background
                CrossingRadialBackground(
                    colorsA: [
                        Color.green.opacity(0.3),
                        Color.blue.opacity(0.2),
                        Color.clear
                    ],
                    colorsB: [
                        Color.green.opacity(0.3),
                        Color.blue.opacity(0.2),
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
                    VStack(spacing: 24) {
                        // Removed Header Section
                        
                        // Form sections with glass effect
                        VStack(spacing: 20) {
                            // Reminder Details Section
                            ModernFormSection(title: "Reminder Details") {
                                VStack(spacing: 16) {
                                    ModernTextField(title: "Reminder Title", text: $title, centered: true)
                                    
                                    if repeatFrequency == .custom {
                                        ModernDatePicker(
                                            title: "Select Time",
                                            selection: $date,
                                            displayedComponents: [.hourAndMinute],
                                            centered: true
                                        )
                                        
                                        HStack {
                                            Image(systemName: "info.circle")
                                                .foregroundColor(.secondary)
                                                .font(.caption)
                                            
                                            Text("This time will apply to all selected dates.")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            
                                            Spacer()
                                        }
                                    } else {
                                        ModernDatePicker(
                                            title: "Select Date and Time",
                                            selection: $date,
                                            displayedComponents: [.date, .hourAndMinute],
                                            centered: true
                                        )
                                    }
                                }
                            }
                            
                            // Repeat Options Section
                            ModernFormSection(title: "Repeat Options") {
                                VStack(spacing: 16) {
                                    ModernCenteredPicker(
                                        title: "Repeat",
                                        selection: $repeatFrequency,
                                        options: RepeatFrequency.allCases
                                    ) { frequency in
                                        Text(frequency.displayName).tag(frequency)
                                    }
                                    .onChange(of: repeatFrequency) { _, _ in
                                        Haptics.selectionChanged()
                                    }
                                    
                                    if repeatFrequency != .none && repeatFrequency != .custom {
                                        ModernStepper(
                                            title: "Interval",
                                            value: $repeatInterval,
                                            range: 1...52,
                                            suffix: repeatFrequency.unitName(for: repeatInterval)
                                        )
                                        
                                        ModernStepper(
                                            title: "Future occurrences",
                                            value: $numberOfOccurrences,
                                            range: 1...50,
                                            suffix: "occurrence\(numberOfOccurrences == 1 ? "" : "s")"
                                        )
                                        
                                        ModernStatusRow(
                                            icon: "info.circle",
                                            iconColor: .blue,
                                            text: "Will create \(numberOfOccurrences + 1) total reminders including the first one"
                                        )
                                    }

                                    if repeatFrequency == .custom {
                                        ModernActionRow(
                                            title: "Choose dates",
                                            icon: "calendar",
                                            action: { Haptics.selectionChanged(); showCustomDatePicker = true }
                                        )
                                        
                                        ModernStatusRow(
                                            icon: customSelectedDates.isEmpty ? "exclamationmark.circle" : "checkmark.circle.fill",
                                            iconColor: customSelectedDates.isEmpty ? .orange : .green,
                                            text: customSelectedDates.isEmpty ? 
                                                "No dates selected yet" : 
                                                "Selected \(customSelectedDates.count) date\(customSelectedDates.count == 1 ? "" : "s")"
                                        )
                                    }
                                    
                                    if repeatFrequency == .none {
                                        ModernStatusRow(
                                            icon: "info.circle",
                                            iconColor: .gray,
                                            text: "This will be a one-time reminder"
                                        )
                                    }
                                }
                            }
                            
                            // Notification Options Section
                            ModernFormSection(title: "Notification Options") {
                                VStack(spacing: 16) {
                                    ModernPicker(
                                        title: "Follow-up interval",
                                        selection: $notificationIntervalMinutes,
                                        options: [1, 2, 5, 10, 15, 30]
                                    ) { minutes in
                                        Text("\(minutes) min").tag(minutes)
                                    }
                                    .onChange(of: notificationIntervalMinutes) { _, _ in
                                        Haptics.selectionChanged()
                                    }
                                    
                                    ModernStepper(
                                        title: "Follow-up count",
                                        value: $notificationRepeatCount,
                                        range: 0...30,
                                        suffix: "follow-up\(notificationRepeatCount == 1 ? "" : "s")"
                                    )
                                    
                                    if notificationRepeatCount == 0 {
                                        ModernStatusRow(
                                            icon: "info.circle",
                                            iconColor: .blue,
                                            text: "Only the initial notification will be sent"
                                        )
                                    }
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
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    Haptics.impact(.medium)
                    dismiss()
                }
                .foregroundColor(.secondary)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Haptics.impact(.medium)
                    save()
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .fontWeight(.semibold)
                .foregroundColor(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .blue)
            }
            ToolbarItem(placement: .principal) {
                TitleBarView(
                    title: "Add Reminder",
                    iconSystemName: "plus.circle.fill",
                    gradientColors: [.green, .blue],
                    topPadding: 32,
                    fontScale: 0.85
                )
            }
        }
        .sheet(isPresented: $showCustomDatePicker) {
            CustomRepeatSelectionView(selectedDates: $customSelectedDates)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .alert("Invalid Date/Time", isPresented: $showInvalidDateAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(invalidDateMessage)
        }
    }

    private func save() {
        let now = Date()
        let normalizedDate = floorToMinute(date)

        // Validate for past date/time
        if repeatFrequency == .custom {
            // Build scheduled dates and ensure at least one is in the future
            let calendar = Calendar.current
            let timeComponents = calendar.dateComponents([.hour, .minute], from: normalizedDate)
            let scheduled: [Date] = customSelectedDates.compactMap { comps in
                var c = comps
                c.hour = timeComponents.hour
                c.minute = timeComponents.minute
                c.second = 0
                return calendar.date(from: c)
            }
            let hasFuture = scheduled.contains { $0 >= now }
            if scheduled.isEmpty || !hasFuture {
                invalidDateMessage = customSelectedDates.isEmpty ?
                    "Please select at least one date." :
                    "All selected dates are in the past. Please choose future dates."
                showInvalidDateAlert = true
                return
            }
        } else {
            if normalizedDate < now {
                invalidDateMessage = "The selected date/time is in the past. Please choose a future time."
                showInvalidDateAlert = true
                return
            }
        }
        
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if repeatFrequency == .custom {
            // Create a parent ID for the custom series
            let parentID = UUID().uuidString
            var remindersToSchedule: [Item] = []
            let calendar = Calendar.current
            // Keep the time components from `date`
            let timeComponents = calendar.dateComponents([.hour, .minute], from: normalizedDate)
            let sortedDates = customSelectedDates.sorted { lhs, rhs in
                let l = calendar.date(from: lhs) ?? Date.distantPast
                let r = calendar.date(from: rhs) ?? Date.distantPast
                return l < r
            }
            for dayComponents in sortedDates {
                var comps = dayComponents
                comps.hour = timeComponents.hour
                comps.minute = timeComponents.minute
                comps.second = 0
                if let scheduledDate = calendar.date(from: comps) {
                    let normalizedScheduled = floorToMinute(scheduledDate, calendar: calendar)
                    let item = Item(
                        timestamp: normalizedScheduled,
                        title: trimmedTitle,
                        repeatFrequency: .custom,
                        parentReminderID: parentID,
                        notificationIntervalMinutes: notificationIntervalMinutes,
                        notificationRepeatCount: notificationRepeatCount,
                        repeatInterval: 1
                    )
                    modelContext.insert(item)
                    remindersToSchedule.append(item)
                }
            }
            try? modelContext.save()
            // Schedule precise in-app triggers for all newly created reminders
            for it in remindersToSchedule {
                inAppNotificationManager.scheduleInAppTrigger(for: it)
            }
            // If any newly created reminder is already due (within a small past grace), show now
            for it in remindersToSchedule where it.timestamp <= now && it.timestamp >= now.addingTimeInterval(-10) {
                inAppNotificationManager.addNotificationSafely(it)
            }
            Task { await NotificationManager.shared.scheduleNotifications(for: remindersToSchedule) }
            dismiss()
            return
        }
        let initial = addRepeatingReminders(
            title: trimmedTitle,
            startDate: normalizedDate,
            repeatFrequency: repeatFrequency,
            repeatInterval: repeatInterval,
            numberOfOccurrences: numberOfOccurrences,
            modelContext: modelContext,
            notificationIntervalMinutes: notificationIntervalMinutes,
            notificationRepeatCount: notificationRepeatCount
        )
        // Schedule precise in-app trigger for the initial reminder
        inAppNotificationManager.scheduleInAppTrigger(for: initial)
        // If the initial reminder is already due (within a small past grace), show now
        if initial.timestamp <= now && initial.timestamp >= now.addingTimeInterval(-10) {
            inAppNotificationManager.addNotificationSafely(initial)
        }
        dismiss()
    }
}



#Preview {
    NavigationStack {
        AddReminderView()
    }
    .modelContainer(for: Item.self, inMemory: true)
}

